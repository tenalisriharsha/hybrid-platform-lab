# The validation environment is a stricter sibling of dev/azure: provisioning
# requires an explicit, out-of-band approval before `terraform plan` will even
# succeed (see the `approved` variable's validation block below) and VMs get
# an env=validation tag instead of env=dev. Credentials still come entirely
# from the standard ARM_* environment variables - never from a tfvars file.
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
  extra_tags      = { env = "validation" }
}

output "vm_id" {
  value = module.vm.vm_id
}

output "name" {
  value = module.vm.name
}
