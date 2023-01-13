output aks_node_pool_subnet_id {
  value                        = azurerm_subnet.aks_node_pool.id
}

output container_apps_environment_subnet_id {
  value                        = azurerm_subnet.container_apps_environment.id
}

output gateway_id {
  value                        = var.gateway_type == "Firewall" ? azurerm_public_ip.gateway.0.id : (var.gateway_type == "NATGateway" ? azurerm_public_ip.nat_egress.0.id : null)
}

output outbound_ip_address {
  value                        = var.gateway_type == "Firewall" ? azurerm_public_ip.gateway.0.ip_address : (var.gateway_type == "NATGateway" ? azurerm_public_ip.nat_egress.0.ip_address : null)
}

output virtual_network_id {
  value                        = azurerm_virtual_network.pipeline_network.id
}