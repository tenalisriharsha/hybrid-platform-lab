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

variable "target_node" {
  type = string
}

variable "template_vm_id" {
  type = number
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "disk_gb" {
  type    = number
  default = 40
}

variable "owner" {
  type = string
}

variable "expiry" {
  type = string
}
