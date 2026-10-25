# The validation environment is a stricter sibling of dev/proxmox: provisioning
# requires an explicit, out-of-band approval before `terraform plan` will even
# succeed (see the `approved` variable's validation block below) and VMs get
# an `env:validation` tag instead of `env:dev`. Connection details still come
# entirely from PROXMOX_VE_* environment variables - never from a tfvars file.
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
  extra_tags     = ["env:validation"]
}

output "vm_id" {
  value = module.vm.vm_id
}

output "name" {
  value = module.vm.name
}
