# Governance check: the validation environment must refuse to plan without
# explicit approval. The approval failure itself happens during variable
# validation, before the provider is ever configured; mock_provider is only
# here so the *approved* run can reach a real plan without real credentials.
mock_provider "proxmox" {}

variables {
  name           = "test-lab-vm"
  target_node    = "pve1"
  template_vm_id = 9000
  owner          = "owner@example.com"
  expiry         = "2099-01-01T00:00:00Z"
}

run "refuses_to_plan_without_approval" {
  command = plan

  variables {
    approved = false
  }

  expect_failures = [var.approved]
}

run "plans_once_approved" {
  command = plan

  variables {
    approved = true
  }
}
