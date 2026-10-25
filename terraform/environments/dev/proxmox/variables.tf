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
