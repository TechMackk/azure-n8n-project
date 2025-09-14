# This script creates two virtual machines in Azure.
#
# Server 1 (N8n): Standard_B2ms, Standard SSD for OS, and an additional Standard SSD data disk.
# Server 2 (Testing): Standard_B1ms, Standard HDD for OS.
#
# Both servers will use a recent Ubuntu LTS image and be located in Central India,
# a region with competitive pricing for users in the Hyderabad area.

# Required providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# --- IMPORTANT: FILL IN YOUR DETAILS BELOW ---
# You need to manually provide your Azure subscription ID here.
# You can find this in the Azure Portal under Subscriptions.
provider "azurerm" {
  features {}
  subscription_id = "25804f04-2009-4009-a51a-ccf3f1576a31"
}

# Define variables for user-configurable values
variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "terraform-vm-rg"
}

variable "location" {
  description = "The Azure region to create the resources in."
  type        = string
  default     = "Central India"
}

variable "admin_username" {
  description = "The admin username for the virtual machines."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "The admin password for the virtual machines."
  type        = string
  sensitive   = true # Mark as sensitive to prevent it from being displayed in logs.
  # IMPORTANT: REPLACE THIS PASSWORD with a secure one. This is a placeholder.
  default     = "$Mackk143"
}

# --- RESOURCE CREATION ---

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet
resource "azurerm_subnet" "main" {
  name                 = "internal-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create a public IP for the N8n server
resource "azurerm_public_ip" "n8n_ip" {
  name                = "n8n-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
}

# Create a public IP for the Testing server
resource "azurerm_public_ip" "testing_ip" {
  name                = "testing-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
}

# Create a Network Security Group (NSG) to allow SSH
resource "azurerm_network_security_group" "main" {
  name                = "nsg-allow-ssh"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # BE CAREFUL: This allows SSH from any IP. Restrict this in a production environment.
    destination_address_prefix = "*"
  }
}

# Create network interfaces for each VM
resource "azurerm_network_interface" "n8n_nic" {
  name                = "n8n-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "n8n-ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.n8n_ip.id
  }
}

resource "azurerm_network_interface" "testing_nic" {
  name                = "testing-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testing-ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.testing_ip.id
  }
}

# Associate the NSG with the network interfaces
resource "azurerm_network_interface_security_group_association" "n8n" {
  network_interface_id      = azurerm_network_interface.n8n_nic.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "testing" {
  network_interface_id      = azurerm_network_interface.testing_nic.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Create the N8n virtual machine
resource "azurerm_linux_virtual_machine" "n8n" {
  name                = "n8n-server"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.n8n_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_SSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Create the separate data disk for the N8n server
resource "azurerm_managed_disk" "n8n_data_disk" {
  name                 = "n8n-data-disk"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_SSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64
}

# Attach the data disk to the N8n server
resource "azurerm_virtual_machine_data_disk_attachment" "n8n_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.n8n_data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.n8n.id
  lun                = 10 # Logical Unit Number
  caching            = "ReadWrite"
}

# Create the Testing virtual machine
resource "azurerm_linux_virtual_machine" "testing" {
  name                = "testing-server"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.testing_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # This corresponds to Standard HDD
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Output the public IP addresses to easily access the VMs
output "n8n_public_ip" {
  value = azurerm_public_ip.n8n_ip.ip_address
}

output "testing_public_ip" {
  value = azurerm_public_ip.testing_ip.ip_address
}