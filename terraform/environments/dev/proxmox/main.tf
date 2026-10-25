# Self-service dev environment: no approval gate, modest default sizing caps.
# Connection details come entirely from the PROXMOX_VE_* environment variables
# the bpg/proxmox provider reads itself - never from a tfvars file - so a
# secret never touches disk. See api/app/backends/proxmox.py.
terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {}

module "vm" {
  source = "../../../modules/proxmox-vm"

  name           = var.name
  target_node    = var.target_node
  template_vm_id = var.template_vm_id
  cpu_cores      = var.cpu_cores
  memory_mb      = var.memory_mb
  disk_gb        = var.disk_gb
  owner          = var.owner
  expiry         = var.expiry
  extra_tags     = ["env:dev"]
}

output "vm_id" {
  value = module.vm.vm_id
}

output "name" {
  value = module.vm.name
}
