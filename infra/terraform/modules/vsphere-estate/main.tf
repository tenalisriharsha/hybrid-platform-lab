resource "vsphere_datacenter" "lab" {
  name = var.datacenter_name
}

resource "vsphere_compute_cluster" "lab" {
  name          = var.cluster_name
  datacenter_id = vsphere_datacenter.lab.id

  drs_enabled = var.drs_enabled
  ha_enabled  = var.ha_enabled
}

resource "vsphere_host" "hosts" {
  for_each = { for host in var.hosts : host.hostname => host }

  hostname = each.value.hostname
  username = each.value.username
  password = var.host_passwords[each.value.hostname]
  license  = each.value.license
  cluster  = vsphere_compute_cluster.lab.id
}

resource "vsphere_nas_datastore" "datastores" {
  for_each = { for datastore in var.datastores : datastore.name => datastore }

  name            = each.value.name
  host_system_ids = toset([for host in values(vsphere_host.hosts) : host.id])
  remote_hosts    = each.value.remote_hosts
  remote_path     = each.value.remote_path
}
