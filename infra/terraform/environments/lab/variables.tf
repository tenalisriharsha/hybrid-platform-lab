variable "vsphere_server" {
  description = "Hostname/IP of the vCenter (or vcsim) endpoint to manage."
  type        = string
}

variable "vsphere_user" {
  description = "vCenter SSO/API user. Never a real credential in this repo — see terraform.tfvars.example."
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vCenter SSO/API password. Never a real credential in this repo — see terraform.tfvars.example."
  type        = string
  sensitive   = true
}

variable "esxi_username" {
  description = "Username used to attach each ESXi host to the cluster."
  type        = string
  sensitive   = true
}

variable "esxi_password" {
  description = "Password used to attach each ESXi host to the cluster."
  type        = string
  sensitive   = true
}
