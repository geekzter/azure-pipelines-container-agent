resource azurerm_private_dns_zone zone {
  for_each                     = var.gateway_type != "NoGateway" ? {
    blob                       = "privatelink.blob.core.windows.net"
    file                       = "privatelink.file.core.windows.net"
    # BUG: ACR private endpoint does not work ACA delegated subnet
    #      https://github.com/microsoft/azure-container-apps/issues/892
    # registry                   = "privatelink.azurecr.io"
    vault                      = "privatelink.vaultcore.azure.net"
  } : {}
  name                         = each.value
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}

resource azurerm_private_dns_zone_virtual_network_link zone_link {
  for_each                     = var.gateway_type != "NoGateway" ? azurerm_private_dns_zone.zone : {}
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-${each.key}"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = each.value.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,1)]
  private_endpoint_network_policies = "Enabled"

  depends_on                   = [
    azurerm_network_security_group.default
  ]
  count                        = var.gateway_type != "NoGateway" ? 1 : 0
}

resource azurerm_private_endpoint diag_blob_storage {
  name                         = "${local.diagnostics_storage_name}-endpoint"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  location                     = azurerm_virtual_network.pipeline_network.location
  
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id

  private_dns_zone_group {
    name                       = azurerm_private_dns_zone.zone["blob"].name
    private_dns_zone_ids       = [azurerm_private_dns_zone.zone["blob"].id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${local.diagnostics_storage_name}-endpoint-connection"
    private_connection_resource_id = var.diagnostics_storage_id
    subresource_names          = ["blob"]
  }

  tags                         = var.tags
  count                        = var.gateway_type != "NoGateway" ? 1 : 0
}

resource azurerm_private_endpoint file_share {
  name                         = "${local.diagnostics_storage_name}-files-endpoint"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  location                     = azurerm_virtual_network.pipeline_network.location
  
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id

  private_dns_zone_group {
    name                       = azurerm_private_dns_zone.zone["file"].name
    private_dns_zone_ids       = [azurerm_private_dns_zone.zone["file"].id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${local.diagnostics_storage_name}-files-endpoint-connection"
    private_connection_resource_id = var.diagnostics_storage_id
    subresource_names          = ["file"]
  }

  tags                         = var.tags
  count                        = var.gateway_type != "NoGateway" ? 1 : 0
}

# BUG: ACR private endpoint does not work ACA delegated subnet
#      https://github.com/microsoft/azure-container-apps/issues/892
# resource azurerm_private_endpoint container_registry {
#   name                       = "${local.container_registry_name}-endpoint-connection"
#   resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
#   location                     = azurerm_virtual_network.pipeline_network.location
  
#   subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id

#   private_dns_zone_group {
#     name                       = azurerm_private_dns_zone.zone["registry"].name
#     private_dns_zone_ids       = [azurerm_private_dns_zone.zone["registry"].id]
#   }

#   private_service_connection {
#     is_manual_connection       = false
#     name                       = "${local.container_registry_name}-endpoint-connection"
#     private_connection_resource_id = var.container_registry_id
#     subresource_names          = ["registry"]
#   }

#   tags                         = var.tags
#   count                        = var.gateway_type != "NoGateway" ? 1 : 0
#   depends_on                   = [azurerm_subnet_route_table_association.private_endpoint_subnet]
# }