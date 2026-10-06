output "container_app_fqdn" {
  value = azurerm_container_app.app.ingress[0].fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "files_storage_account" {
  value = azurerm_storage_account.files.name
}

output "app_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}

output "admin_api_key" {
  value     = random_password.admin_api_key.result
  sensitive = true
}

output "chatbot_api_key" {
  value     = random_password.chatbot_api_key.result
  sensitive = true
}
