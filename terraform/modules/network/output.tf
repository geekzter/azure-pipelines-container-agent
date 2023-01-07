output container_apps_environment_subnet_id {
  value                        = azurerm_subnet.container_apps_environment.id
}

output gateway_id {
  value                        = var.deploy_firewall ? azurerm_public_ip.gateway.0.id : azurerm_public_ip.nat_egress.0.id
}

output outbound_ip_address {
  value                        = var.deploy_firewall ? azurerm_public_ip.gateway.0.ip_address : azurerm_public_ip.nat_egress.0.ip_address
}

output virtual_network_id {
  value                        = azurerm_virtual_network.pipeline_network.id
}