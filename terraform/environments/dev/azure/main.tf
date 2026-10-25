# Self-service dev environment: no approval gate, modest default sizing caps.
# Credentials come entirely from the standard ARM_* environment variables the
# azurerm provider reads itself - never from a tfvars file. See
# api/app/backends/azure.py.
terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "vm" {
  source = "../../../modules/azure-vm"

  name            = var.name
  location        = var.location
  vm_size         = var.vm_size
  ssh_public_key  = var.ssh_public_key
  image_publisher = var.image_publisher
  image_offer     = var.image_offer
  image_sku       = var.image_sku
  image_version   = var.image_version
  owner           = var.owner
  expiry          = var.expiry
  extra_tags      = { env = "dev" }
}

output "vm_id" {
  value = module.vm.vm_id
}

output "name" {
  value = module.vm.name
}
