variable "resource_group_name" {
  description = "The name of the Resource Group to be created."
  type        = string
  default     = "Terraform-RG-2"
}

variable "location" {
  description = "Azure region to create the resources."
  type        = string
  default     = "East US"
}

variable "admin_username" {
  description = "Linux VM admin username."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Linux VM admin password."
  type        = string
  sensitive   = true
}

variable "vm_count" {
  description = "Number of VMs to create."
  type        = number
  default     = 2
}