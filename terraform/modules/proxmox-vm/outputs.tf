output "vm_id" {
  description = "The numeric Proxmox VMID of the cloned VM."
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "name" {
  description = "The VM's name."
  value       = proxmox_virtual_environment_vm.vm.name
}

output "node_name" {
  description = "The Proxmox node the VM was placed on."
  value       = proxmox_virtual_environment_vm.vm.node_name
}
