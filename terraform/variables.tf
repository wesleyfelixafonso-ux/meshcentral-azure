variable "subscription_id" {
  description = "Subscription do Azure onde tudo será criado."
  type        = string
}

variable "hostname" {
  description = "Nome público do MeshCentral (ex.: remoto.suaempresa.com.br). Vai gravado em todos os agentes: trocar depois exige reinstalar o agente nas máquinas."
  type        = string
}

variable "project_name" {
  description = "Prefixo dos recursos. Letras minúsculas, números e hífen."
  type        = string
  default     = "remote-access"
}

variable "environment" {
  description = "Ambiente, usado no nome dos recursos."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Região do Azure."
  type        = string
  default     = "brazilsouth"
}

variable "location_short" {
  description = "Abreviação da região, usada no nome dos recursos."
  type        = string
  default     = "brs"
}

variable "tags" {
  description = "Tags extras para todos os recursos."
  type        = map(string)
  default     = {}
}

variable "site_title" {
  description = "Título do site (aba do navegador e cabeçalho)."
  type        = string
  default     = "Acesso Remoto"
}

variable "site_subtitle" {
  description = "Subtítulo do site."
  type        = string
  default     = ""
}

variable "meshcentral_version" {
  description = "Tag da imagem ghcr.io/ylianst/meshcentral. Trocar aqui e aplicar = atualização."
  type        = string
  default     = "1.3.1"
}

variable "cpu" {
  description = "vCPU do container."
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memória do container (combinações válidas do Container Apps: 0.5 vCPU = 1Gi)."
  type        = string
  default     = "1Gi"
}

variable "storage_replication" {
  description = "Replicação do storage: LRS (mais barato) ou GRS (cópia em outra região)."
  type        = string
  default     = "GRS"
}

variable "storage_delete_lock" {
  description = "Cria a trava CanNotDelete no storage (recomendado em produção)."
  type        = bool
  default     = true
}

variable "recordings_quota_gb" {
  description = "Cota do share de gravações (GB)."
  type        = number
  default     = 20
}

variable "recording_days" {
  description = "Dias que as gravações de sessão ficam guardadas."
  type        = number
  default     = 30
}

variable "backup_keep_days" {
  description = "Dias que os backups diários (zip com senha) ficam guardados."
  type        = number
  default     = 14
}

variable "allowed_ips" {
  description = "IPs/CIDRs que podem acessar o app. Vazio = aberto para a internet (necessário para os agentes). Use só durante a criação da conta admin."
  type        = list(string)
  default     = []
}

variable "google_client_id" {
  description = "Client ID do OAuth do Google (tela de consentimento do tipo Interno). Vazio = login só por usuário/senha com 2FA."
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Client secret do OAuth do Google."
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_new_accounts" {
  description = "Deixa o primeiro login pelo Google criar a conta. A conta nasce sem acesso a máquinas; o admin dá as permissões."
  type        = bool
  default     = true
}

variable "show_password_login" {
  description = "Mostra o formulário de usuário/senha no login. Com Google ligado: true até as contas Google receberem as permissões, depois false. A conta admin local continua existindo para emergência."
  type        = bool
  default     = true
}

variable "login_tokens_enabled" {
  description = "Permite criar token de login (acesso por API/meshctrl). false = acesso só pela interface."
  type        = bool
  default     = false
}
