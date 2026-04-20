variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the new resource group"
  type        = string
}

variable "environment_name" {
  description = "Base name used for all resources"
  type        = string
  default     = "aca-logstoeventhub"
}

# Existing VNet/Subnet references
variable "vnet_resource_group_name" {
  description = "Resource group of the existing VNet"
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing VNet"
  type        = string
}

variable "subnet_name" {
  description = "Name of the existing subnet to inject the Container App Environment into"
  type        = string
}
