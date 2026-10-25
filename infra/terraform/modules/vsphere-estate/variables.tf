variable "datacenter_name" {
  description = "Name of the vSphere datacenter that houses the lab's compute cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the vSphere compute cluster the hosts are attached to."
  type        = string
}

variable "drs_enabled" {
  description = "Whether DRS is enabled on the compute cluster."
  type        = bool
  default     = true
}

variable "ha_enabled" {
  description = "Whether HA is enabled on the compute cluster."
  type        = bool
  default     = true
}

variable "hosts" {
  description = <<-EOT
    ESXi hosts to attach to the compute cluster. Capacity numbers (CPU
    cores, memory) are intentionally not modeled here: they belong to the
    real hardware behind each hostname and are observed live through the
    HybridPlatformSync PowerCLI module, not declared as code. Passwords are
    supplied separately via `host_passwords` so this list can stay
    non-sensitive and usable as a for_each key.
  EOT
  type = list(object({
    hostname = string
    username = string
    license  = optional(string)
  }))

  validation {
    condition     = length(var.hosts) > 0
    error_message = "At least one host must be defined."
  }

  validation {
    condition     = length(distinct([for h in var.hosts : h.hostname])) == length(var.hosts)
    error_message = "Host hostnames must be unique."
  }
}

variable "host_passwords" {
  description = "Map of host hostname to the password used to attach it. Never a real credential in example files."
  type        = map(string)
  sensitive   = true

  validation {
    condition     = length(setsubtract([for h in var.hosts : h.hostname], keys(var.host_passwords))) == 0
    error_message = "Every host in `hosts` must have a matching entry in `host_passwords`."
  }
}

variable "datastores" {
  description = "NAS datastores to mount across every host in the cluster."
  type = list(object({
    name         = string
    remote_hosts = list(string)
    remote_path  = string
  }))
  default = []

  validation {
    condition     = length(distinct([for d in var.datastores : d.name])) == length(var.datastores)
    error_message = "Datastore names must be unique."
  }
}
