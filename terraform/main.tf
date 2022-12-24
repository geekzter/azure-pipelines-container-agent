# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  numeric                      = false
  special                      = false
}

locals {
  user_assigned_identity_id    = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? var.user_assigned_identity_id : azurerm_user_assigned_identity.agents.0.id
  owner                        = var.application_owner != "" ? var.application_owner : data.azurerm_client_config.default.object_id
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  tags                         = merge(
    {
      application              = var.application_name
      github-repo              = "https://github.com/geekzter/azure-pipelines-container-agent"
      owner                    = local.owner
      provisioner              = "terraform"
      provisioner-client-id    = data.azurerm_client_config.default.client_id
      provisioner-object-id    = data.azurerm_client_config.default.object_id
      repository               = "azure-pipelines-container-agent"
      runid                    = var.run_id
      suffix                   = local.suffix
      workspace                = terraform.workspace
    },
    var.tags
  )  
}

resource azurerm_resource_group rg {
  name                         = terraform.workspace == "default" ? "${var.resource_prefix}-container-agents-${local.suffix}" : "${var.resource_prefix}-${terraform.workspace}-container-agents-${local.suffix}"
  location                     = var.location

  tags                         = local.tags
}

resource azurerm_ssh_public_key ssh_key {
  name                         = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  public_key                   = file(var.ssh_public_key)

  tags                         = azurerm_resource_group.rg.tags
}

resource azurerm_user_assigned_identity agents {
  name                         = "${azurerm_resource_group.rg.name}-agent-identity"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location

  count                        = var.user_assigned_identity_id != "" && var.user_assigned_identity_id != null ? 0 : 1
  tags                         = local.tags
}