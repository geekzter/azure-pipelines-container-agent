resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  sku_name                     = "Standard"

  tags                         = var.tags

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}

resource azurerm_public_ip nat_egress {
  name                         = "${azurerm_nat_gateway.egress.0.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}
resource azurerm_monitor_diagnostic_setting nat_egress {
  name                         = "${azurerm_public_ip.nat_egress.0.name}-logs"
  target_resource_id           = azurerm_public_ip.nat_egress.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "DDoSProtectionNotifications"
  }
  enabled_log {
    category                   = "DDoSMitigationFlowLogs"
  }
  enabled_log {
    category                   = "DDoSMitigationReports"
  }  

  enabled_metric {
    category                   = "AllMetrics"
  }

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
} 

resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id
  public_ip_address_id         = azurerm_public_ip.nat_egress.0.id

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association aks_node_pool {
  subnet_id                    = azurerm_subnet.aks_node_pool.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [
    azurerm_nat_gateway_public_ip_association.egress,
  ]

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association bastion_subnet {
  subnet_id                    = azurerm_subnet.bastion_subnet.0.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [
    azurerm_nat_gateway_public_ip_association.egress,
  ]

  count                        = var.deploy_bastion && var.gateway_type == "NATGateway" ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association container_apps_environment {
  subnet_id                    = azurerm_subnet.container_apps_environment.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [
    azurerm_nat_gateway_public_ip_association.egress,
  ]

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association private_endpoint_subnet {
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [
    azurerm_nat_gateway_public_ip_association.egress,
  ]

  count                        = var.gateway_type == "NATGateway" ? 1 : 0
}