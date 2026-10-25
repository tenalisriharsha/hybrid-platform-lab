variable "name" {
  description = "VM name; also used to derive the resource group/network/NIC names."
  type        = string
}

variable "location" {
  description = "Azure region to provision into."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size (e.g. Standard_B2s)."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM."
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key authorized for admin_username."
  type        = string
}

variable "address_space" {
  description = "Address space for the VM's dedicated virtual network."
  type        = string
  default     = "10.100.0.0/24"
}

variable "subnet_prefix" {
  description = "Subnet prefix carved out of address_space."
  type        = string
  default     = "10.100.0.0/26"
}

variable "image_publisher" {
  description = "Marketplace image publisher."
  type        = string
}

variable "image_offer" {
  description = "Marketplace image offer."
  type        = string
}

variable "image_sku" {
  description = "Marketplace image SKU."
  type        = string
}

variable "image_version" {
  description = "Marketplace image version."
  type        = string
  default     = "latest"
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
  description = "Additional tags to merge in (e.g. the environment folder, dev/validation)."
  type        = map(string)
  default     = {}
}
