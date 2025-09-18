terraform {
  backend "azurerm" {
    resource_group_name  = "Terraform-Backend-RG"
    storage_account_name = "techmackkstorage123"   # use your storage account name created in Step 1
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}