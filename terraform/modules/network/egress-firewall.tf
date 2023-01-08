resource azurerm_subnet gateway {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,0)]

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_subnet firewall_management {
  name                         = "AzureFirewallManagementSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,1)]

  count                        = var.gateway_type == "Firewall" && var.firewall_sku_tier == "Basic" ? 1 : 0
}


resource azurerm_ip_group agents {
  name                         = "${var.resource_group_name}-gw-agents"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = local.agent_prefixes

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_ip_group vnet {
  name                         = "${var.resource_group_name}-gw-vnet"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = azurerm_virtual_network.pipeline_network.address_space

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_ip_group azdo {
  name                         = "${var.resource_group_name}-gw-azdo"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [
    # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#ip-addresses-and-range-restrictions
    "13.107.6.0/24",
    "13.107.9.0/24",
    "13.107.42.0/24",
    "13.107.43.0/24",
  ]

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_ip_group microsoft_365 {
  name                         = "${var.resource_group_name}-gw-m365"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [
    # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#other-ip-addresses
    "40.82.190.38",
    "52.108.0.0/14",
    "52.237.19.6",
    "52.238.106.116/32",
    "52.244.37.168/32",
    "52.244.203.72/32",
    "52.244.207.172/32",
    "52.244.223.198/32",
    "52.247.150.191/32",
  ]

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_public_ip gateway {
  name                         = "${var.resource_group_name}-gw-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_public_ip firewall_management {
  name                         = "${var.resource_group_name}-gwmgmt-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" && var.firewall_sku_tier == "Basic" ? 1 : 0
}

resource azurerm_firewall gateway {
  name                         = "${var.resource_group_name}-gw"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  sku_name                     = "AZFW_VNet"
  sku_tier                     = var.firewall_sku_tier

  dynamic management_ip_configuration {
    for_each = range(var.firewall_sku_tier == "Basic" ? 1 : 0) 
    content {
      name                     = "gw_mgmt_ipconfig"
      public_ip_address_id     = azurerm_public_ip.firewall_management.0.id
      subnet_id                = azurerm_subnet.firewall_management.0.id
    }
  }

  dns_servers                  = var.firewall_sku_tier == "Standard" || var.firewall_sku_tier == "Premium" ? ["168.63.129.16"] : null
  firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
  ip_configuration {
    name                       = "gw_ipconfig"
    subnet_id                  = azurerm_subnet.gateway.0.id
    public_ip_address_id       = azurerm_public_ip.gateway.0.id
  }

  tags                         = var.tags

  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.agents
  ]
  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_virtual_network_dns_servers dns_proxy {
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id
  dns_servers                  = [azurerm_firewall.gateway.0.ip_configuration.0.private_ip_address]

  count                        = var.gateway_type == "Firewall" && (var.firewall_sku_tier == "Standard" || var.firewall_sku_tier == "Premium") ? 1 : 0
}

resource azurerm_firewall_policy gateway {
  name                         = "${var.resource_group_name}-gw"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = var.firewall_sku_tier

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_firewall_policy_rule_collection_group agents {
  name                         = "agents"
  firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
  priority                     = 500

  network_rule_collection {
    name                       = "AgentNetworkRules"
    priority                   = 400
    action                     = "Allow"
    rule {
      name                     = "AllowAllOutbound"
      protocols                = ["Any"]
      source_ip_groups         = [azurerm_ip_group.vnet.0.id]
      destination_addresses    = ["*"]
      destination_ports        = ["*"]
    }
  }

  depends_on                   = [
    # https://github.com/hashicorp/terraform-provider-azurerm/issues/19843
    azurerm_ip_group.agents,
    azurerm_ip_group.azdo,
    azurerm_ip_group.microsoft_365,
    azurerm_ip_group.vnet
  ]

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting firewall_ip_logs {
  name                         = "${azurerm_public_ip.gateway.0.name}-logs"
  target_resource_id           = azurerm_public_ip.gateway.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting firewall_logs {
  name                         = "${azurerm_firewall.gateway.0.name}-logs"
  target_resource_id           = azurerm_firewall.gateway.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  log {
    category                   = "AzureFirewallDnsProxy"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "AzureFirewallApplicationRule"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "AzureFirewallNetworkRule"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  
  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_route_table gateway {
  name                         = "${azurerm_firewall.gateway.0.name}-routes"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  route {
    name                       = "VnetLocal"
    address_prefix             = var.address_space
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "InternetViaFW"
    address_prefix             = "0.0.0.0/0"
    next_hop_type              = "VirtualAppliance"
    next_hop_in_ip_address     = azurerm_firewall.gateway.0.ip_configuration.0.private_ip_address
  }
  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_subnet_route_table_association container_apps_environment {
  subnet_id                    = azurerm_subnet.container_apps_environment.id
  route_table_id               = azurerm_route_table.gateway.0.id

  count                        = var.gateway_type == "Firewall" ? 1 : 0
  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.agents,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}