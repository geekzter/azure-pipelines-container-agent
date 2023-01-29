locals {
  peer_network_name            = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
}

data azurerm_virtual_network peered_network {
  name                         = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
  resource_group_name          = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-5)

  count                        = var.peer_network_id == "" ? 0 : 1
}

resource azurerm_virtual_network_peering network_to_peer {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-to-peer"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  remote_virtual_network_id    = data.azurerm_virtual_network.peered_network.0.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = var.peer_network_has_gateway

  count                        = var.peer_network_id == "" ? 0 : 1

  depends_on                   = [azurerm_virtual_network_peering.peer_to_network]
}

resource azurerm_virtual_network_peering peer_to_network {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-from-peer"
  resource_group_name          = data.azurerm_virtual_network.peered_network.0.resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.peered_network.0.name
  remote_virtual_network_id    = azurerm_virtual_network.pipeline_network.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.peer_network_has_gateway
  allow_virtual_network_access = true
  use_remote_gateways          = false

  count                        = var.peer_network_id == "" ? 0 : 1
}