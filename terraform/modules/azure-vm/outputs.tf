output "vm_id" {
  description = "The Azure resource ID of the VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "The VM's name."
  value       = azurerm_linux_virtual_machine.this.name
}

output "resource_group_name" {
  description = "The resource group the VM (and its network) was created in."
  value       = azurerm_resource_group.this.name
}

output "private_ip_address" {
  description = "The VM's private IP address."
  value       = azurerm_linux_virtual_machine.this.private_ip_address
}
