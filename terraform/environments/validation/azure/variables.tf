variable "approved" {
  description = "Must be explicitly set to true by whoever is running this plan/apply - the validation environment is gated, unlike dev."
  type        = bool
  default     = false

  validation {
    condition     = var.approved == true
    error_message = "the validation environment requires approved = true; this is not something a self-service request can set on its own."
  }
}

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
