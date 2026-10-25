terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.6"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

module "estate" {
  source = "../../modules/vsphere-estate"

  datacenter_name = "hpl-lab-dc"
  cluster_name    = "hpl-lab-cluster"

  hosts = [
    {
      hostname = "esx-01.hpl.lab"
      username = var.esxi_username
      license  = null
    },
    {
      hostname = "esx-02.hpl.lab"
      username = var.esxi_username
      license  = null
    },
  ]

  host_passwords = {
    "esx-01.hpl.lab" = var.esxi_password
    "esx-02.hpl.lab" = var.esxi_password
  }

  datastores = [
    {
      name         = "hpl-datastore-01"
      remote_hosts = ["nfs.hpl.lab"]
      remote_path  = "/export/hpl-datastore-01"
    },
  ]
}

output "cluster_id" {
  value = module.estate.cluster_id
}

output "datastore_ids" {
  value = module.estate.datastore_ids
}
