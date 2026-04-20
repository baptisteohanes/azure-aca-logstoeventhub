output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.this.name
}

output "container_app_fqdn" {
  description = "Public FQDN of the Hello World container app"
  value       = azurerm_container_app.hello.ingress[0].fqdn
}

output "container_app_url" {
  description = "Full URL of the Hello World container app"
  value       = "https://${azurerm_container_app.hello.ingress[0].fqdn}"
}

output "eventhub_namespace" {
  description = "Event Hub namespace receiving logs"
  value       = azurerm_eventhub_namespace.this.name
}

output "eventhub_name" {
  description = "Event Hub receiving all diagnostic logs"
  value       = azurerm_eventhub.logs.name
}
