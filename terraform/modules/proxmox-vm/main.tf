# Clones a VM from an existing Proxmox template. owner/expiry are never real
# Proxmox fields - they are encoded as tags (hybrid-lab:, owner:, expiry:) so
# they survive a `pvesh get` / UI inspection the same way vSphere Notes do for
# the vsphere backend (see powercli/HybridLab/Private/LabMarkerNotes.ps1).
resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name
  node_name = var.target_node
  started   = var.started

  clone {
    vm_id = var.template_vm_id
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_gb
  }

  network_device {
    bridge = var.network_bridge
  }

  tags = concat(
    ["hybrid-lab", "owner:${var.owner}", "expiry:${var.expiry}"],
    var.extra_tags,
  )
}
