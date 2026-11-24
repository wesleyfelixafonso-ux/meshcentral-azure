locals {
  name   = var.project_name
  prefix = "${var.project_name}-${var.environment}-${var.location_short}"
  tags = merge({
    application = var.project_name
    environment = var.environment
    managed-by  = "terraform"
  }, var.tags)

  # Storage e Key Vault têm nome global: o sufixo aleatório evita colisão com outros tenants.
  compact_name = substr(replace(var.project_name, "-", ""), 0, 14)
  storage_name = "st${local.compact_name}${random_string.suffix.result}"
  kv_name      = substr("kv-${var.project_name}-${random_string.suffix.result}", 0, 24)

  google_enabled = var.google_client_id != ""
  mesh_root      = "/opt/meshcentral"
  # share → quota (GB). meshcentral-web serve o tema (public/ sobrepõe os estáticos do MeshCentral).
  mesh_shares = {
    "meshcentral-data"       = 5
    "meshcentral-files"      = 5
    "meshcentral-backups"    = 5
    "meshcentral-web"        = 1
    "meshcentral-recordings" = var.recordings_quota_gb
  }

  # Tema (theme/): os logos vão para meshcentral-data (titlePicture/loginPicture só aceitam
  # PNG/JPEG de lá); CSS, JS e fontes para meshcentral-web/public.
  theme_dir   = "${path.module}/theme"
  theme_fonts = fileset("${path.module}/theme/fonts", "*.woff2")
  theme_hash = sha256(join("", [for f in concat(
    ["theme.css", "theme.js", "logo-header.png", "logo-header-light.png", "logo-login.png"],
    [for x in local.theme_fonts : "fonts/${x}"]
  ) : filesha256("${local.theme_dir}/${f}")]))

  # config.json do MeshCentral, gravado no Azure Files e lido pelo container
  # (a imagem oficial usa o arquivo como está quando DYNAMIC_CONFIG=false).
  meshcentral_config = {
    settings = {
      cert        = var.hostname
      port        = 80 # o ingress do Container Apps termina o TLS e entrega HTTP na 80
      aliasPort   = 443
      redirPort   = 0
      tlsOffload  = true
      WANonly     = true
      agentPing   = 60 # mantém o websocket dos agentes vivo atrás do ingress
      browserPing = 60
      autoBackup = {
        backupIntervalHours = 24
        keepLastDaysBackup  = var.backup_keep_days
        backupPath          = "${local.mesh_root}/meshcentral-backups"
        zipPassword         = random_password.backup_zip.result
      }
    }
    domains = {
      "" = merge(
        {
          title        = var.site_title
          title2       = var.site_subtitle
          siteStyle    = 3
          titlePicture = "logo-header.png"
          loginPicture = "logo-login.png"
          customFiles  = { theme = { css = ["theme.css"], js = ["theme.js"], scope = ["all"] } }
          # Grava sessões de tela e terminal (1 = terminal, 2 = desktop).
          sessionRecording = {
            filepath         = "${local.mesh_root}/meshcentral-recordings"
            index            = true
            maxRecordingDays = var.recording_days
            protocols        = [1, 2]
          }
          newAccounts       = false # contas novas só pelo Google; a 1ª conta local ainda pode ser criada (vira admin)
          showPasswordLogin = var.show_password_login
          certUrl           = "https://${var.hostname}:443/" # hash do certificado público para os agentes
          passwordRequirements = {
            min          = 14
            force2factor = true
            loginTokens  = var.login_tokens_enabled # token de login = acesso por API/meshctrl
          }
        },
        local.google_enabled ? {
          authStrategies = {
            google = {
              clientid          = var.google_client_id
              clientsecret      = var.google_client_secret
              callbackurl       = "https://${var.hostname}/auth-google-callback"
              newAccounts       = var.google_new_accounts
              newAccountsRights = ["nonewgroups", "notools"] # conta nova nasce sem acesso a máquinas
            }
          }
        } : {}
      )
    }
  }
  meshcentral_config_json = jsonencode(local.meshcentral_config)
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

# ── Segredos ──────────────────────────────────────────────────────────────────
resource "random_password" "admin" {
  length           = 24
  special          = true
  min_special      = 2
  override_special = "!#%*-_=+:.,"
}

resource "random_password" "backup_zip" {
  length  = 40
  special = false
}

resource "azurerm_key_vault" "main" {
  name                       = local.kv_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  tags                       = local.tags
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "meshcentral-admin-password"
  value        = random_password.admin.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "backup_zip_password" {
  name         = "meshcentral-backup-zip-password"
  value        = random_password.backup_zip.result
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "google_client_secret" {
  count        = local.google_enabled ? 1 : 0
  name         = "google-client-secret"
  value        = var.google_client_secret
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.deployer]
}

# ── Armazenamento persistente (Azure Files) ───────────────────────────────────
# meshcentral-data guarda os certificados do servidor: se for perdida, todos os agentes
# ficam órfãos. Proteções: soft delete de share, replicação geográfica (opcional) e trava
# CanNotDelete (cobre exclusão da conta ou de um share).
resource "azurerm_storage_account" "main" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  share_properties {
    retention_policy {
      days = 14
    }
  }
}

resource "azurerm_management_lock" "storage" {
  count      = var.storage_delete_lock ? 1 : 0
  name       = "nao-apagar-dados-meshcentral"
  scope      = azurerm_storage_account.main.id
  lock_level = "CanNotDelete"
  notes      = "Guarda os certificados do servidor MeshCentral: apagar deixa todos os agentes órfãos. Restaure o backup antes de qualquer recriação."
}

resource "azurerm_storage_share" "mesh" {
  for_each           = local.mesh_shares
  name               = each.key
  storage_account_id = azurerm_storage_account.main.id
  quota              = each.value
}

# ── Tema ──────────────────────────────────────────────────────────────────────
resource "azurerm_storage_share_file" "logo" {
  for_each          = toset(["logo-header.png", "logo-login.png"])
  name              = each.key
  storage_share_url = azurerm_storage_share.mesh["meshcentral-data"].url
  source            = "${local.theme_dir}/${each.key}"
  content_md5       = filemd5("${local.theme_dir}/${each.key}")
  content_type      = "image/png"
}

# Encadeados: o Azure Files só cria um diretório se o pai já existir.
resource "azurerm_storage_share_directory" "web_public" {
  name              = "public"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
}

resource "azurerm_storage_share_directory" "web_styles" {
  name              = "public/styles"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  depends_on        = [azurerm_storage_share_directory.web_public]
}

resource "azurerm_storage_share_directory" "web_fonts" {
  name              = "public/styles/fonts"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  depends_on        = [azurerm_storage_share_directory.web_styles]
}

resource "azurerm_storage_share_directory" "web_scripts" {
  name              = "public/scripts"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  depends_on        = [azurerm_storage_share_directory.web_public]
}

resource "azurerm_storage_share_file" "theme_js" {
  name              = "theme.js"
  path              = "public/scripts"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  source            = "${local.theme_dir}/theme.js"
  content_md5       = filemd5("${local.theme_dir}/theme.js")
  content_type      = "text/javascript"
  depends_on        = [azurerm_storage_share_directory.web_scripts]
}

# Logo do modo claro (texto escuro) para a barra superior; o do escuro vem do titlePicture.
resource "azurerm_storage_share_file" "theme_logo_light" {
  name              = "logo-header-light.png"
  path              = "public/styles"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  source            = "${local.theme_dir}/logo-header-light.png"
  content_md5       = filemd5("${local.theme_dir}/logo-header-light.png")
  content_type      = "image/png"
  depends_on        = [azurerm_storage_share_directory.web_styles]
}

resource "azurerm_storage_share_file" "theme_css" {
  name              = "theme.css"
  path              = "public/styles"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  source            = "${local.theme_dir}/theme.css"
  content_md5       = filemd5("${local.theme_dir}/theme.css")
  content_type      = "text/css"
  depends_on        = [azurerm_storage_share_directory.web_fonts]
}

resource "azurerm_storage_share_file" "theme_font" {
  for_each          = local.theme_fonts
  name              = each.key
  path              = "public/styles/fonts"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-web"].url
  source            = "${local.theme_dir}/fonts/${each.key}"
  content_md5       = filemd5("${local.theme_dir}/fonts/${each.key}")
  content_type      = "font/woff2"
  depends_on        = [azurerm_storage_share_directory.web_fonts]
}

resource "local_sensitive_file" "config" {
  filename = "${path.module}/.generated/config.json"
  content  = local.meshcentral_config_json
}

resource "azurerm_storage_share_file" "config" {
  name              = "config.json"
  storage_share_url = azurerm_storage_share.mesh["meshcentral-data"].url
  source            = local_sensitive_file.config.filename
  content_md5       = local_sensitive_file.config.content_md5
}

# ── Container Apps ────────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Só o perfil Consumption: sem perfil dedicado, sem janela de manutenção e sem private
# endpoint não há taxa de gestão do ambiente.
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.prefix}-cae"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app_environment_storage" "mesh" {
  for_each                     = azurerm_storage_share.mesh
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = each.value.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "main" {
  name                         = substr("${local.prefix}-ca", 0, 32) # limite de 32 caracteres
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  template {
    # 1 réplica fixa: os agentes ficam conectados 24h e o MeshCentral não roda em paralelo
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "meshcentral"
      image  = "ghcr.io/ylianst/meshcentral:${var.meshcentral_version}"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "CONFIG_FILE"
        value = "${local.mesh_root}/meshcentral-data/config.json"
      }
      env {
        name  = "DYNAMIC_CONFIG"
        value = "false"
      }
      env {
        # muda quando o config.json ou o tema mudam: gera revisão nova, que relê os arquivos
        name  = "CONFIG_SHA"
        value = sha256("${local.meshcentral_config_json}${local.theme_hash}")
      }

      dynamic "volume_mounts" {
        for_each = local.mesh_shares
        content {
          name = volume_mounts.key
          path = "${local.mesh_root}/${volume_mounts.key}"
        }
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 80
        path                    = "/health.ashx"
        initial_delay           = 60
        interval_seconds        = 30
        failure_count_threshold = 5
      }
    }

    dynamic "volume" {
      for_each = azurerm_container_app_environment_storage.mesh
      content {
        name         = volume.key
        storage_type = "AzureFile"
        storage_name = volume.value.name
      }
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

    dynamic "ip_security_restriction" {
      for_each = var.allowed_ips
      content {
        name             = "permitido-${ip_security_restriction.key}"
        action           = "Allow"
        ip_address_range = ip_security_restriction.value
      }
    }
  }

  depends_on = [azurerm_storage_share_file.config, azurerm_storage_share_file.logo, azurerm_storage_share_file.theme_css, azurerm_storage_share_file.theme_js, azurerm_storage_share_file.theme_logo_light, azurerm_storage_share_file.theme_font]
}
