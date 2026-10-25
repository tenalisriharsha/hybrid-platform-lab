variable "name" {
  description = "VM name, also used as the Proxmox VM name."
  type        = string
}

variable "target_node" {
  description = "Proxmox node to place the cloned VM on."
  type        = string
}

variable "template_vm_id" {
  description = "VMID of the Proxmox template to clone from."
  type        = number
}

variable "cpu_cores" {
  description = "Number of CPU cores."
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Memory in MB."
  type        = number
  default     = 4096
}

variable "disk_gb" {
  description = "Primary disk size in GB."
  type        = number
  default     = 40
}

variable "datastore_id" {
  description = "Proxmox datastore to place the disk on."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge to attach the VM's NIC to."
  type        = string
  default     = "vmbr0"
}

variable "owner" {
  description = "Email of the person the VM was provisioned for; recorded as a tag."
  type        = string
}

variable "expiry" {
  description = "RFC3339 timestamp the VM should be torn down by; recorded as a tag."
  type        = string
}

variable "extra_tags" {
  description = "Additional Proxmox tags to attach (e.g. the environment folder, dev/validation)."
  type        = list(string)
  default     = []
}

variable "started" {
  description = "Whether the cloned VM should be powered on after creation."
  type        = bool
  default     = false
}
