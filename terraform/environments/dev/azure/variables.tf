variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "ssh_public_key" {
  type = string
}

variable "image_publisher" {
  type = string
}

variable "image_offer" {
  type = string
}

variable "image_sku" {
  type = string
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "owner" {
  type = string
}

variable "expiry" {
  type = string
}
