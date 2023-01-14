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
  # firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
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

  dns {
    proxy_enabled              = var.firewall_sku_tier == "Standard" || var.firewall_sku_tier == "Premium"
  }

  insights {
    enabled                    = true
    default_log_analytics_workspace_id=var.log_analytics_workspace_resource_id
  }

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-network-rules
# Only rules that have no dependency on AKS being created first
resource azurerm_firewall_network_rule_collection iag_net_outbound_rules {
  name                         = "${azurerm_firewall.gateway.0.name}-network-rules"
  azure_firewall_name          = azurerm_firewall.gateway.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 1001
  action                       = "Allow"

  rule {
    name                       = "AllowOutboundAKSAPIServer1"
    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    destination_ports          = ["1194"]
    destination_addresses      = [
      "AzureCloud.${var.location}",
    ]
    protocols                  = ["UDP"]
  }
  rule {
    name                       = "AllowOutboundAKSAPIServer2"
    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    destination_ports          = ["9000"]
    destination_addresses      = [
      "AzureCloud.${var.location}",
    ]
    protocols                  = ["TCP"]
  }
  rule {
    name                       = "AllowOutboundAKSAPIServerHTTPS"
    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    destination_ports          = ["443"]
    destination_addresses      = [
      "AzureCloud.${var.location}",
    ]
    protocols                  = ["TCP"]
  }
  
  rule {
    name                       = "AllowUbuntuNTP"
    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    destination_ports          = ["123"]
    destination_fqdns          = [
      "ntp.ubuntu.com",
    ]
    protocols                  = ["UDP"]
  }
  rule {
    name                       = "AllowNTP"
    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    destination_ports          = ["123"]
    destination_fqdns          = [
      "pool.ntp.org",
    ]
    protocols                  = ["UDP"]
  }

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
resource azurerm_firewall_application_rule_collection aks_app_rules {
  name                         = "${azurerm_firewall.gateway.0.name}-app-rules"
  azure_firewall_name          = azurerm_firewall.gateway.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 2001
  action                       = "Allow"

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  rule {
    name                       = "Allow outbound traffic"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "*.hcp.${var.location}.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#optional-recommended-fqdn--application-rules-for-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (recommended)"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "security.ubuntu.com",
      "azure.archive.ubuntu.com",
      "changelogs.ubuntu.com",
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (GPU enabled nodes)"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "nvidia.github.io",
      "*.download.nvidia.com",
      "apt.dockerproject.org",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (Windows enabled nodes)"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "onegetcdn.azureedge.net",
      "go.microsoft.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (Windows enabled nodes, port 80)"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "*.mp.microsoft.com",
      "www.msftconnecttest.com",
      "ctldl.windowsupdate.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-monitor-for-containers
  rule {
    name                       = "Allow outbound AKS Azure Monitor traffic"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "dc.services.visualstudio.com",
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.monitoring.azure.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#required-network-rules-1
  rule {
    name                       = "Allow DevSpaces"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    fqdn_tags                  = ["AzureDevSpaces"]
  }


  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-dev-spaces
  rule {
    name                       = "Allow outbound AKS Dev Spaces"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "cloudflare.docker.com",
      "gcr.io",
      "storage.googleapis.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-policy
  rule {
    name                       = "Allow outbound AKS Azure Policy"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "data.policy.core.windows.net",
      "store.policy.core.windows.net",
      "gov-prod-policy-data.trafficmanager.net",
      "raw.githubusercontent.com",
      "dc.services.visualstudio.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall
  # Not required for private AKS, which uses a Private Endpoint
  # rule {
  #   name                       = "Allow outbound AKS"

  #   source_ip_groups           = [azurerm_ip_group.agents.0.id]
  #   fqdn_tags                  = ["AzureKubernetesService"]
  # }

  # Traffic required, but not documented
  rule {
    name                       = "Allow misc container management traffic"

    source_ip_groups           = [azurerm_ip_group.agents.0.id]
    target_fqdns               = [
      "api.snapcraft.io",
      "auth.docker.io",
      "github.com",
      "ifconfig.co",
      "motd.ubuntu.com",
      "production.cloudflare.docker.com",
      "registry-1.docker.io",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  count                        = var.gateway_type == "Firewall" ? 1 : 0
} 

resource azurerm_firewall_application_rule_collection agent_app_rules {
  name                         = "${azurerm_firewall.gateway.0.name}-agent-app-rules"
  azure_firewall_name          = azurerm_firewall.gateway.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 200
  action                       = "Allow"

  rule {
    name                       = "AllowAllHttpOutbound"

    protocol {
      type                     = "Http"
      port                     = 80
    }

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    target_fqdns               = [
      "*"
    ]
  }

  rule {
    name                       = "AllowAllHttpsOutbound"

    protocol {
      type                     = "Https"
      port                     = 443
    }

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    target_fqdns               = [
      "*"
    ]
  }

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}
resource azurerm_firewall_network_rule_collection agent_allow_all_outbound {
  name                         = "${azurerm_firewall.gateway.0.name}-agent-net-out-debug-rules"
  azure_firewall_name          = azurerm_firewall.gateway.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 201
  action                       = "Allow"


  rule {
    name                       = "Allow All Outbound"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "*"
    ]
    destination_addresses      = [
      "*", 
    ]

    protocols                  = [
      "Any"
    ]
  }

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

  # AKS (in kubelet network mode) may add routes Terraform is not aware off
  lifecycle {
    ignore_changes             = [
                                 route
    ]
  }  

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}


resource azurerm_subnet_route_table_association aks_node_pool {
  subnet_id                    = azurerm_subnet.aks_node_pool.id
  route_table_id               = azurerm_route_table.gateway.0.id

  count                        = var.gateway_type == "Firewall" ? 1 : 0
  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.agents,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}

# BUG: https://github.com/microsoft/azure-container-apps/issues/227
# resource azurerm_subnet_route_table_association container_apps_environment {
#   subnet_id                    = azurerm_subnet.container_apps_environment.id
#   route_table_id               = azurerm_route_table.gateway.0.id

#   count                        = var.gateway_type == "Firewall" ? 1 : 0
#   depends_on                   = [
#     azurerm_firewall_policy_rule_collection_group.agents,
#     azurerm_monitor_diagnostic_setting.firewall_logs,
#   ]
# }