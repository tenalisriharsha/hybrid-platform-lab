mock_provider "azurerm" {}

variables {
  name     = "test-lab-vm"
  location = "eastus"
  # A throwaway key generated solely for this test fixture; its private half was
  # never saved anywhere, so it authenticates nothing.
  ssh_public_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoKvgDQioDGxNPCnokvwiY9yAIxOjLXWz1j8MXnlTI7 hybrid-lab-test-key"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  owner           = "owner@example.com"
  expiry          = "2099-01-01T00:00:00Z"
}

run "creates_resource_group_and_vm_with_expected_names" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.name == "test-lab-vm-rg"
    error_message = "resource group name should be derived from the VM name"
  }

  assert {
    condition     = azurerm_resource_group.this.location == "eastus"
    error_message = "resource group should be created in the requested location"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.name == "test-lab-vm"
    error_message = "VM name should match the name variable"
  }
}

run "defaults_to_a_small_size_and_disables_password_auth" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_B2s"
    error_message = "default vm_size should be Standard_B2s"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication == true
    error_message = "password authentication should always be disabled; SSH key only"
  }

  assert {
    condition     = one(azurerm_linux_virtual_machine.this.admin_ssh_key).public_key == var.ssh_public_key
    error_message = "the admin SSH key should match the ssh_public_key variable"
  }
}

run "overrides_vm_size" {
  command = plan

  variables {
    vm_size = "Standard_D4s_v5"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_D4s_v5"
    error_message = "vm_size override should be honored"
  }
}

run "uses_the_requested_marketplace_image" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.source_image_reference[0].publisher == "Canonical"
    error_message = "image publisher should match the image_publisher variable"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.source_image_reference[0].sku == "22_04-lts-gen2"
    error_message = "image sku should match the image_sku variable"
  }
}

run "tags_carry_owner_and_expiry_markers" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.tags["owner"] == "owner@example.com"
    error_message = "the owner tag should match the owner variable"
  }

  assert {
    condition     = azurerm_resource_group.this.tags["expiry"] == "2099-01-01T00:00:00Z"
    error_message = "the expiry tag should match the expiry variable"
  }

  assert {
    condition     = azurerm_resource_group.this.tags["hybrid-lab"] == "true"
    error_message = "every lab resource group should carry the hybrid-lab tag"
  }
}

run "extra_tags_are_merged_in" {
  command = plan

  variables {
    extra_tags = { env = "dev" }
  }

  assert {
    condition     = azurerm_resource_group.this.tags["env"] == "dev"
    error_message = "extra_tags entries should be merged into the tag map"
  }
}
