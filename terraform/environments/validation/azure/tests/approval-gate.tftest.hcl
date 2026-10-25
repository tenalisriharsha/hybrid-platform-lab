# Governance check: the validation environment must refuse to plan without
# explicit approval. The approval failure itself happens during variable
# validation, before the provider is ever configured; mock_provider is only
# here so the *approved* run can reach a real plan without real credentials.
mock_provider "azurerm" {}

variables {
  name            = "test-lab-vm"
  location        = "eastus"
  ssh_public_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoKvgDQioDGxNPCnokvwiY9yAIxOjLXWz1j8MXnlTI7 hybrid-lab-test-key"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  owner           = "owner@example.com"
  expiry          = "2099-01-01T00:00:00Z"
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
