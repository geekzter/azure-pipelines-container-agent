locals {
  container_app_address_prefixes = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],1,1)]  
  aks_address_prefixes         = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],2,1)]  
  agent_prefixes               = concat(local.container_app_address_prefixes,local.aks_address_prefixes)
}

resource azurerm_subnet aks_node_pool {
  name                         = "KubernetesClusterNodes"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.aks_address_prefixes
  depends_on                   = [
    azurerm_network_security_rule.inbound_agent_rdp,
    azurerm_network_security_rule.inbound_agent_ssh,
  ]
}

resource azurerm_subnet container_apps_environment {
  name                         = "ContainerAppsEnvironment"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.container_app_address_prefixes

  delegation {
    name                       = "delegation"

    service_delegation {
      name                     = "Microsoft.App/environments"
      actions                  = [
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action", 
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      ]
    }
  }

  depends_on                   = [
    azurerm_network_security_rule.inbound_agent_rdp,
    azurerm_network_security_rule.inbound_agent_ssh,
  ]
}

resource azurerm_network_security_group agent_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-agent-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}

resource azurerm_network_security_rule inbound_agent_ssh {
  name                         = "AllowSSH"
  priority                     = 201
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefixes      = azurerm_subnet.bastion_subnet.0.address_prefixes
  destination_address_prefixes = local.agent_prefixes
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule inbound_agent_rdp {
  name                         = "AllowRDP"
  priority                     = 202
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefixes      = azurerm_subnet.bastion_subnet.0.address_prefixes
  destination_address_prefixes = local.agent_prefixes
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name

  count                        = var.deploy_bastion ? 1 : 0
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule inbound_agent_lb {
  name                         = "AllowLoadBalancer"
  priority                     = 203
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "AzureLoadBalancer"
  destination_address_prefixes = local.agent_prefixes
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule internal1 {
  name                         = "InboundInternal"
  priority                     = 204
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefixes = local.agent_prefixes
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule internal2 {
  name                         = "OutboundInternal"
  priority                     = 301
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefixes = local.agent_prefixes
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule outbound_aks_1194 {
  name                         = "AllowAksUDP"
  priority                     = 302
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Udp"
  source_port_range            = "*"
  destination_port_range       = "1194"
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefix   = "AzureCloud.${var.location}"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule outbound_aks_9000 {
  name                         = "AllowAksTCP"
  priority                     = 303
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "9000"
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefix   = "AzureCloud.${var.location}"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule outbound_monitor {
  name                         = "AllowMonitor"
  priority                     = 304
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefix   = "AzureMonitor"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
# BUG: Unsupported value used: MicrosoftContainerRegistry
# resource azurerm_network_security_rule outbound_registry {
#   name                         = "AllowRegistry"
#   priority                     = 305
#   direction                    = "Outbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "443"
#   source_address_prefixes      = local.agent_prefixes
#   destination_address_prefixes = [
#     "MicrosoftContainerRegistry",
#     "AzureFrontDoor.FirstParty"
#   ]
#   resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.agent_nsg.name
# }
# https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules
resource azurerm_network_security_rule outbound_wildcard {
  name                         = "AllowWildcards"
  priority                     = 306
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["123","443","5671","5672"]
  source_address_prefixes      = local.agent_prefixes
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
# TODO: More ACA rules needed?: https://github.com/microsoft/azure-container-apps/issues/893

resource azurerm_subnet_network_security_group_association aks_node_pool {
  subnet_id                    = azurerm_subnet.aks_node_pool.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore changes made by policy
    ]
  }
}

resource azurerm_subnet_network_security_group_association container_apps_environment {
  subnet_id                    = azurerm_subnet.container_apps_environment.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore changes made by policy
    ]
  }
}