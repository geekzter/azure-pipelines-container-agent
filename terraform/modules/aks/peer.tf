locals {
  peer_network_name            = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
}

# Set up name resolution for peered network
resource azurerm_private_dns_zone_virtual_network_link api_server_domain {
  name                         = "${local.peer_network_name}-zone-link"
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group
  private_dns_zone_name        = data.azurerm_private_dns_zone.api_server_domain.0.name
  virtual_network_id           = var.peer_network_id

  tags                         = var.tags

  count                        = var.peer_network_id != "" && var.private_cluster_enabled ? 1 : 0
}