# No real provider, network, or vCenter/vcsim connection is used here: the
# vsphere provider is fully mocked, so these tests only check that the
# module builds the expected plan given a set of inputs.
mock_provider "vsphere" {}

variables {
  datacenter_name = "test-dc"
  cluster_name    = "test-cluster"
  hosts = [
    { hostname = "esx-01.test.lab", username = "root", license = null },
    { hostname = "esx-02.test.lab", username = "root", license = null },
  ]
  host_passwords = {
    "esx-01.test.lab" = "test-pass"
    "esx-02.test.lab" = "test-pass"
  }
  datastores = [
    { name = "test-ds-01", remote_hosts = ["nfs.test.lab"], remote_path = "/export/ds01" },
  ]
}

run "plans_expected_topology" {
  # apply against the mocked provider only: no real network or vCenter/vcsim
  # call happens, but it resolves the mocked "computed" ids this run's
  # assertions need (e.g. datacenter_id), which `plan` alone leaves unknown.
  command = apply

  assert {
    condition     = vsphere_datacenter.lab.name == "test-dc"
    error_message = "datacenter name should pass through from the datacenter_name variable"
  }

  assert {
    condition     = vsphere_compute_cluster.lab.name == "test-cluster"
    error_message = "cluster name should pass through from the cluster_name variable"
  }

  assert {
    condition     = vsphere_compute_cluster.lab.datacenter_id == vsphere_datacenter.lab.id
    error_message = "cluster should be created inside the module's own datacenter"
  }

  assert {
    condition     = length(vsphere_host.hosts) == 2
    error_message = "one vsphere_host resource should be planned per entry in the hosts variable"
  }

  assert {
    condition     = alltrue([for h in vsphere_host.hosts : h.cluster == vsphere_compute_cluster.lab.id])
    error_message = "every host should be attached to the module's compute cluster"
  }

  assert {
    condition     = length(vsphere_nas_datastore.datastores) == 1
    error_message = "one vsphere_nas_datastore resource should be planned per entry in the datastores variable"
  }

  assert {
    condition     = vsphere_nas_datastore.datastores["test-ds-01"].remote_path == "/export/ds01"
    error_message = "datastore remote_path should pass through from the datastores variable"
  }
}

run "defaults_to_no_datastores" {
  command = plan

  variables {
    datastores = []
  }

  assert {
    condition     = length(vsphere_nas_datastore.datastores) == 0
    error_message = "omitting datastores should plan a cluster with no datastores, not an error"
  }
}

run "rejects_empty_hosts" {
  command = plan

  variables {
    hosts = []
  }

  expect_failures = [
    var.hosts,
  ]
}

run "rejects_duplicate_host_names" {
  command = plan

  variables {
    hosts = [
      { hostname = "esx-01.test.lab", username = "root", license = null },
      { hostname = "esx-01.test.lab", username = "root", license = null },
    ]
  }

  expect_failures = [
    var.hosts,
  ]
}

run "rejects_missing_host_password" {
  command = plan

  variables {
    host_passwords = {
      "esx-01.test.lab" = "test-pass"
    }
  }

  expect_failures = [
    var.host_passwords,
  ]
}

run "rejects_duplicate_datastore_names" {
  command = plan

  variables {
    datastores = [
      { name = "dup", remote_hosts = ["nfs.test.lab"], remote_path = "/export/a" },
      { name = "dup", remote_hosts = ["nfs.test.lab"], remote_path = "/export/b" },
    ]
  }

  expect_failures = [
    var.datastores,
  ]
}
