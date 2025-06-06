resource azurerm_subnet gateway {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,0)]

  count                        = var.gateway_type == "Firewall" ? 1 : 0
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

resource azurerm_firewall gateway {
  name                         = "${var.resource_group_name}-gw"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  sku_name                     = "AZFW_VNet"
  sku_tier                     = "Standard"


  firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
  ip_configuration {
    name                       = "gw_ipconfig"
    subnet_id                  = azurerm_subnet.gateway.0.id
    public_ip_address_id       = azurerm_public_ip.gateway.0.id
  }

  tags                         = var.tags

  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.network,
    azurerm_firewall_policy_rule_collection_group.outbound_open
  ]
  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_virtual_network_dns_servers dns_proxy {
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id
  dns_servers                  = [azurerm_firewall.gateway.0.ip_configuration.0.private_ip_address,"168.63.129.16"]

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_firewall_policy gateway {
  name                         = "${var.resource_group_name}-gw"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "Standard"

  dns {
    proxy_enabled              = true
  }

  insights {
    enabled                    = true
    default_log_analytics_workspace_id=var.log_analytics_workspace_resource_id
  }

  tags                         = var.tags

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_firewall_policy_rule_collection_group network {
  name                         = "network"
  firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
  priority                     = 400

  # https://learn.microsoft.com/en-us/azure/container-apps/networking?tabs=azure-cli#network-rules
  network_rule_collection {
    name                       = "AcaOutboundNetworkRules"
    priority                   = 400
    action                     = "Allow"

    rule {
      name                     = "All scenarios"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_addresses    = [
        "MicrosoftContainerRegistry",
        "AzureFrontDoorFirstParty",
        "AzureFrontDoor.FirstParty"
      ]
      destination_ports        = ["*"]
      protocols                = ["Any"]
    }
    rule {
      name                     = "Azure Container Registry (ACR)"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_addresses    = [
        "AzureContainerRegistry",
        "AzureActiveDirectory"
      ]
      destination_ports        = ["*"]
      protocols                = ["Any"]
    }
    rule {
      name                     = "Azure Key Vault"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_addresses    = [
        "AzureKeyVault",
        "AzureActiveDirectory"
      ]
      destination_ports        = ["*"]
      protocols                = ["Any"]
    }
    rule {
      name                     = "Managed Identity"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_addresses    = [
        "AzureActiveDirectory"
      ]
      destination_ports        = ["*"]
      protocols                = ["Any"]
    }

  }

  network_rule_collection {
    name                       = "AksOutboundNetworkRules"
    priority                   = 401
    action                     = "Allow"

    rule {
      name                     = "AllowOutboundAKSAPIServer1"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_ports        = ["1194"]
      destination_addresses    = [
        "AzureCloud.${var.location}",
      ]
      protocols                = ["UDP"]
    }
    rule {
      name                     = "AllowOutboundAKSAPIServer2"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_ports        = ["9000"]
      destination_addresses    = [
        "AzureCloud.${var.location}",
      ]
      protocols                = ["TCP"]
    }
    rule {
      name                     = "AllowOutboundAKSAPIServerHTTPS"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_ports        = ["443"]
      destination_addresses    = [
        "AzureCloud.${var.location}",
      ]
      protocols                = ["TCP"]
    }
    
    rule {
      name                     = "AllowUbuntuNTP"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_ports        = ["123"]
      destination_fqdns        = [
        "ntp.ubuntu.com",
      ]
      protocols                = ["UDP"]
    }
    rule {
      name                     = "AllowNTP"
      source_ip_groups         = [azurerm_ip_group.agents.0.id]
      destination_ports        = ["123"]
      destination_fqdns        = [
        "pool.ntp.org",
      ]
      protocols                = ["UDP"]
    }
  }

  # https://learn.microsoft.com/en-us/azure/container-apps/networking?tabs=azure-cli#application-rules
  application_rule_collection {
    name                       = "AcaOutboundApplicationRules"
    priority                   = 402
    action                     = "Allow"

    rule {
      name                       = "All scenarios"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    rule {
      name                       = "Azure Container Registry (ACR)"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        data.azurerm_container_registry.registry.login_server,
        "*.blob.windows.net",
        "login.microsoft.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # rule {
    #   name                       = "Azure Key Vault"

    #   source_ip_groups           = [azurerm_ip_group.agents.0.id]
    #   destination_fqdns          = [
    #     "Your-Azure-Key-Vault-address",
    #     "login.microsoft.com",
    #   ]

    #   protocols {
    #     port                     = "443"
    #     type                     = "Https"
    #   }
    # }

    rule {
      name                       = "Managed Identity"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "*.identity.azure.net",
        "login.microsoftonline.com",
        "*.login.microsoftonline.com", 
        "*.login.microsoft.com"
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    rule {
      name                       = "Docker Hub Registry"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "hub.docker.com",
        "registry-1.docker.io",
        "production.cloudflare.docker.com",
      ]

      protocols {
        port                     = "80"
        type                     = "Http"
      }

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }
  }

  application_rule_collection {
    name                       = "AksOutboundApplicationRules"
    priority                   = 403
    action                     = "Allow"

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
    rule {
      name                       = "Allow outbound traffic"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "*.hcp.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#optional-recommended-fqdn--application-rules-for-aks-clusters
    rule {
      name                       = "Allow outbound AKS optional traffic (recommended)"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "security.ubuntu.com",
        "azure.archive.ubuntu.com",
        "changelogs.ubuntu.com",
      ]

      protocols {
        port                     = "80"
        type                     = "Http"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
    rule {
      name                       = "Allow outbound AKS optional traffic (GPU enabled nodes)"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "nvidia.github.io",
        "*.download.nvidia.com",
        "apt.dockerproject.org",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
    rule {
      name                       = "Allow outbound AKS optional traffic (Windows enabled nodes)"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "onegetcdn.azureedge.net",
        "go.microsoft.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic#required-fqdn--application-rules-1
    rule {
      name                       = "Allow outbound AKS optional traffic (Windows enabled nodes, port 80)"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdns          = [
        "*.mp.microsoft.com",
        "www.msftconnecttest.com",
        "ctldl.windowsupdate.com",
      ]

      protocols {
        port                     = "80"
        type                     = "Http"
      }

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-monitor-for-containers
    rule {
      name                       = "Allow outbound AKS Defender & Azure Monitor traffic"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdn_tags      = [
        "dc.services.visualstudio.com",
        "login.microsoftonline.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-policy
    rule {
      name                       = "Allow outbound AKS Azure Policy"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdn_tags      = [
        "data.policy.core.windows.net",
        "store.policy.core.windows.net",
        "gov-prod-policy-data.trafficmanager.net",
        "raw.githubusercontent.com",
        "dc.services.visualstudio.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic#cluster-extensions
    rule {
      name                       = "Allow outbound AKS Cluster Extensions"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdn_tags      = [
        "${var.location}.dp.kubernetesconfiguration.azure.com",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
      ]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
    }

    # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall
    # Not required for private AKS, which uses a Private Endpoint
    rule {
      name                       = "Allow outbound AKS"

      source_ip_groups           = [azurerm_ip_group.agents.0.id]
      destination_fqdn_tags      = ["AzureKubernetesService"]

      protocols {
        port                     = "443"
        type                     = "Https"
      }
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

resource azurerm_firewall_policy_rule_collection_group outbound_open {
  name                         = "agents"
  firewall_policy_id           = azurerm_firewall_policy.gateway.0.id
  priority                     = 500

  network_rule_collection {
    name                       = "OpenOutboundNetworkRules"
    priority                   = 500
    action                     = "Allow"
    rule {
      name                     = "AllowAllOutbound"
      protocols                = ["Any"]
      source_ip_groups         = [azurerm_ip_group.vnet.0.id]
      destination_addresses    = ["*"]
      destination_ports        = ["*"]
    }
  }

  application_rule_collection {
    name                       = "OpenOutboundApplicationRules"
    priority                   = 501
    action                     = "Allow"

    rule {
      name                     = "AllowAllHttpOutbound"

      protocols {
        type                   = "Http"
        port                   = 80
      }

      protocols {
        type                   = "Https"
        port                   = 443
      }

      source_ip_groups         = [
        azurerm_ip_group.vnet.0.id
      ]

      destination_fqdns        = [
        "*"
      ]
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

  count                        = var.gateway_type == "Firewall" ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting firewall_logs {
  name                         = "${azurerm_firewall.gateway.0.name}-logs"
  target_resource_id           = azurerm_firewall.gateway.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "AzureFirewallDnsProxy"
  }

  enabled_log {
    category                   = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category                   = "AzureFirewallNetworkRule"
  }
  
  enabled_metric {
    category                   = "AllMetrics"
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
    azurerm_firewall_policy_rule_collection_group.network,
    azurerm_firewall_policy_rule_collection_group.outbound_open,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}

resource azurerm_subnet_route_table_association container_apps_environment {
  subnet_id                    = azurerm_subnet.container_apps_environment.id
  route_table_id               = azurerm_route_table.gateway.0.id

  count                        = var.gateway_type == "Firewall" ? 1 : 0
  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.network,
    azurerm_firewall_policy_rule_collection_group.outbound_open,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}

resource azurerm_subnet_route_table_association private_endpoint_subnet {
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id
  route_table_id               = azurerm_route_table.gateway.0.id

  count                        = var.gateway_type == "Firewall" ? 1 : 0
  depends_on                   = [
    azurerm_firewall_policy_rule_collection_group.network,
    azurerm_firewall_policy_rule_collection_group.outbound_open,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}