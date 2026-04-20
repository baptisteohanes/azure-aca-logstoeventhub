terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.2"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Existing subnet (must be delegated to Microsoft.App/environments)
# ---------------------------------------------------------------------------
data "azurerm_subnet" "aca" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

# ---------------------------------------------------------------------------
# Event Hub – dedicated namespace + hub for this deployment's logs
# ---------------------------------------------------------------------------
resource "azurerm_eventhub_namespace" "this" {
  name                = "evhns-${var.environment_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurerm_eventhub" "logs" {
  name              = "evh-${var.environment_name}-logs"
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = 2
  message_retention = 1
}

# Shared access policy used by the diagnostic settings to send logs
resource "azurerm_eventhub_namespace_authorization_rule" "send" {
  name                = "DiagnosticSendRule"
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = azurerm_resource_group.this.name
  listen              = false
  send                = true
  manage              = false
}

# ---------------------------------------------------------------------------
# Container App Environment – VNet-injected
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "this" {
  name                           = "cae-${var.environment_name}"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  infrastructure_subnet_id       = data.azurerm_subnet.aca.id
  internal_load_balancer_enabled = false # public ingress
}

# ---------------------------------------------------------------------------
# Diagnostic settings – send ALL Container App Environment logs to Event Hub
# Covers system logs (ContainerAppSystemLogs) and app logs
# (ContainerAppConsoleLogs) plus any metrics.
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "cae" {
  name                           = "diag-cae-to-eventhub"
  target_resource_id             = azurerm_container_app_environment.this.id
  eventhub_name                  = azurerm_eventhub.logs.name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.send.id

  # Send every available log category
  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Container App – simple "Hello World" (nginx welcome page)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "hello" {
  name                         = "ca-hello-world"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  template {
    container {
      name   = "hello-world"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# Diagnostic settings for the Container App itself (app-level logs)
resource "azurerm_monitor_diagnostic_setting" "ca" {
  name                           = "diag-ca-to-eventhub"
  target_resource_id             = azurerm_container_app.hello.id
  eventhub_name                  = azurerm_eventhub.logs.name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.send.id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }
}
