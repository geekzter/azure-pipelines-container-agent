locals {
  container_registry_id        = var.container_registry_id != null && var.container_registry_id != "" ? var.container_registry_id : azurerm_container_registry.image_registry.0.id
  container_registry_name      = element(split("/",local.container_registry_id),length(split("/",local.container_registry_id))-1)
}

resource azurerm_container_registry image_registry {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(var.suffix,-6,-1)}agent"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.container_registry_id != null && var.container_registry_id != "" ? 0 : 1
}

resource azurerm_role_assignment agent_registry_access {
  scope                        = local.container_registry_id
  role_definition_name         = "AcrPush"
  principal_id                 = var.agent_identity_id

  count                        = (var.agent_identity_id == "" || var.agent_identity_id == null) && var.configure_access_control ? 1 : 0
}
