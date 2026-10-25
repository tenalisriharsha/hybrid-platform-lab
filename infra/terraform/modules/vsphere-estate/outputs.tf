output "datacenter_id" {
  description = "ID of the created vSphere datacenter."
  value       = vsphere_datacenter.lab.id
}

output "cluster_id" {
  description = "ID of the created vSphere compute cluster."
  value       = vsphere_compute_cluster.lab.id
}

output "host_ids" {
  description = "Map of host hostname to the resulting vSphere host ID."
  value       = { for hostname, host in vsphere_host.hosts : hostname => host.id }
}

output "datastore_ids" {
  description = "Map of datastore name to the resulting vSphere datastore ID."
  value       = { for name, datastore in vsphere_nas_datastore.datastores : name => datastore.id }
}
