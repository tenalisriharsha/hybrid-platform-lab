mock_provider "proxmox" {}

variables {
  name           = "test-lab-vm"
  target_node    = "pve1"
  template_vm_id = 9000
  owner          = "owner@example.com"
  expiry         = "2099-01-01T00:00:00Z"
}

run "clones_from_the_requested_template" {
  command = apply

  assert {
    condition     = proxmox_virtual_environment_vm.vm.clone[0].vm_id == 9000
    error_message = "the VM should clone from the template VMID passed in"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.node_name == "pve1"
    error_message = "the VM should land on the requested node"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.started == false
    error_message = "a newly cloned lab VM should default to powered off"
  }
}

run "applies_default_sizing" {
  command = apply

  assert {
    condition     = proxmox_virtual_environment_vm.vm.cpu[0].cores == 2
    error_message = "default cpu_cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.memory[0].dedicated == 4096
    error_message = "default memory_mb should be 4096"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.disk[0].size == 40
    error_message = "default disk_gb should be 40"
  }
}

run "overrides_sizing" {
  command = apply

  variables {
    cpu_cores = 8
    memory_mb = 16384
    disk_gb   = 160
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.cpu[0].cores == 8
    error_message = "cpu_cores override should be honored"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.memory[0].dedicated == 16384
    error_message = "memory_mb override should be honored"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.vm.disk[0].size == 160
    error_message = "disk_gb override should be honored"
  }
}

run "tags_carry_owner_and_expiry_markers" {
  command = apply

  assert {
    condition     = contains(proxmox_virtual_environment_vm.vm.tags, "hybrid-lab")
    error_message = "every lab VM should carry the hybrid-lab tag"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.vm.tags, "owner:owner@example.com")
    error_message = "the owner tag should match the owner variable"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.vm.tags, "expiry:2099-01-01T00:00:00Z")
    error_message = "the expiry tag should match the expiry variable"
  }
}

run "extra_tags_are_merged_in" {
  command = apply

  variables {
    extra_tags = ["env:dev"]
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.vm.tags, "env:dev")
    error_message = "extra_tags entries should be merged into the tag list"
  }

  assert {
    condition     = contains(proxmox_virtual_environment_vm.vm.tags, "hybrid-lab")
    error_message = "extra_tags should not replace the base tags"
  }
}

run "network_bridge_defaults_and_overrides" {
  command = apply

  assert {
    condition     = proxmox_virtual_environment_vm.vm.network_device[0].bridge == "vmbr0"
    error_message = "default network_bridge should be vmbr0"
  }
}
