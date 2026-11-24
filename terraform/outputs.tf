output "url" {
  value = "https://${var.hostname}"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "container_app_name" {
  value = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  value = azurerm_container_app.main.ingress[0].fqdn
}

output "environment_name" {
  description = "Ambiente do Container Apps (usado no bind do certificado gerenciado)"
  value       = azurerm_container_app_environment.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "dns_cname" {
  description = "Registro CNAME a criar no seu DNS"
  value       = "${var.hostname}. CNAME ${azurerm_container_app.main.ingress[0].fqdn}."
}

output "dns_asuid_txt" {
  description = "Registro TXT de verificação do domínio no Container App"
  value       = "asuid.${var.hostname}. TXT ${azurerm_container_app.main.custom_domain_verification_id}"
  sensitive   = true
}

output "google_callback_url" {
  description = "URI de redirecionamento autorizado no cliente OAuth do Google"
  value       = "https://${var.hostname}/auth-google-callback"
}
