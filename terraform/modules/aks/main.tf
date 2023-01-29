locals {
  kubernetes_version           = var.kubernetes_version != null && var.kubernetes_version != "" ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name          = element(split("/",var.resource_group_id),length(split("/",var.resource_group_id))-1)
}

data azurerm_subscription primary {}

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-1)
  virtual_network_name         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-3)
  resource_group_name          = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-7)
}

data azurerm_user_assigned_identity aks_identity {
  name                         = element(split("/",var.user_assigned_identity_id),length(split("/",var.user_assigned_identity_id))-1)
  resource_group_name          = element(split("/",var.user_assigned_identity_id),length(split("/",var.user_assigned_identity_id))-5)
}

# Required to manage identity on kubelets
resource azurerm_role_assignment spn_identity_operator {
  scope                        = var.user_assigned_identity_id
  role_definition_name         = "Managed Identity Operator"
  principal_id                 = data.azurerm_user_assigned_identity.aks_identity.principal_id

  count                        = var.configure_access_control && !var.user_assigned_identity_is_precreated ? 1 : 0
}

resource azurerm_role_assignment spn_metrics_publisher {
  scope                        = var.resource_group_id
  role_definition_name         = "Monitoring Metrics Publisher"
  principal_id                 = data.azurerm_user_assigned_identity.aks_identity.principal_id

  count                        = var.configure_access_control ? 1 : 0
}

# AKS needs permission to make changes for kubelet networking mode
resource azurerm_role_assignment spn_network_contributor {
  scope                        = var.resource_group_id
  role_definition_name         = "Network Contributor"
  principal_id                 = data.azurerm_user_assigned_identity.aks_identity.principal_id

  count                        = var.configure_access_control ? 1 : 0
}

# AKS needs permission for BYO DNS
resource azurerm_role_assignment spn_dns_contributor {
  scope                        = var.resource_group_id
  role_definition_name         = "Private DNS Zone Contributor"
  principal_id                 = data.azurerm_user_assigned_identity.aks_identity.principal_id

  count                        = var.configure_access_control && var.private_cluster_enabled ? 1 : 0
}

# Requires Terraform owner access to resource group, in order to be able to perform access management
resource azurerm_role_assignment spn_vm_contributor {
  scope                        = var.resource_group_id
  role_definition_name         = "Virtual Machine Contributor"
  principal_id                 = data.azurerm_user_assigned_identity.aks_identity.principal_id

  count                        = var.configure_access_control ? 1 : 0
}

# Grant Terraform user Cluster Admin role
resource azurerm_role_assignment terraform_cluster_admin {
  scope                        = var.resource_group_id
  role_definition_name         = "Azure Kubernetes Service Cluster Admin Role"
  principal_id                 = var.client_object_id

  count                        = var.configure_access_control ? 1 : 0
}
resource azurerm_role_assignment terraform_cluster_user {
  scope                        = var.resource_group_id
  role_definition_name         = "Azure Kubernetes Service Cluster User Role"
  principal_id                 = var.client_object_id

  count                        = var.configure_access_control ? 1 : 0
}

data azurerm_kubernetes_service_versions current {
  location                     = var.location
  include_preview              = false
}

resource azurerm_resource_provider_registration keda {
  name                         = "Microsoft.ContainerService"
  feature {
    name                       = "AKS-KedaPreview"
    registered                 = true
  }

  count                        = var.enable_keda ? 1 : 0
}

resource azurerm_kubernetes_cluster aks {
  name                         = "${local.resource_group_name}-k8s"
  location                     = var.location
  resource_group_name          = local.resource_group_name
  node_resource_group          = "${local.resource_group_name}-k8s-nodes"
  dns_prefix                   = var.dns_prefix

  # Triggers resource to be recreated
  kubernetes_version           = local.kubernetes_version

  automatic_channel_upgrade    = "stable"

  dynamic azure_active_directory_role_based_access_control {
    for_each = range(var.configure_access_control ? 1 : 0) 
    content {
      admin_group_object_ids   = [var.client_object_id]
      azure_rbac_enabled       = true
      managed                  = true
    }
  }  

  azure_policy_enabled         = true

  default_node_pool {
    enable_auto_scaling        = true
    enable_host_encryption     = false # Requires 'Microsoft.Compute/EncryptionAtHost' feature
    enable_node_public_ip      = var.enable_node_public_ip
    min_count                  = var.node_min_count
    max_count                  = var.node_max_count
    name                       = "default"
    node_count                 = var.node_min_count
    tags                       = var.tags
    # https://docs.microsoft.com/en-us/azure/virtual-machines/disk-encryption#supported-vm-sizes
    vm_size                    = var.node_size
    vnet_subnet_id             = var.node_subnet_id
  }

  http_application_routing_enabled = true

  identity {
    type                       = "UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  kubelet_identity {
    client_id                  = data.azurerm_user_assigned_identity.aks_identity.client_id
    object_id                  = data.azurerm_user_assigned_identity.aks_identity.principal_id
    user_assigned_identity_id  = var.user_assigned_identity_id
  }

  # local_account_disabled       = true

  network_profile {
    network_plugin             = var.network_plugin
    network_policy             = var.network_policy
    outbound_type              = var.network_outbound_type
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  private_cluster_enabled      = var.private_cluster_enabled
  private_dns_zone_id          = var.private_cluster_enabled ? "System" : null
  #private_cluster_public_fqdn_enabled = true

  role_based_access_control_enabled = true

  workload_autoscaler_profile {
    keda_enabled               = var.enable_keda
  }

  lifecycle {
    ignore_changes             = [
      default_node_pool.0.node_count, # Ignore changes made by autoscaling

      # BUG: kubelet_identity triggers replacement in azurerm 3.39.1
      kubelet_identity.0.client_id,
      kubelet_identity.0.object_id,
      workload_autoscaler_profile.0.keda_enabled # Can be configured post-provisioning
    ]
  }

  tags                         = var.tags

  depends_on                   = [
    # azurerm_resource_provider_registration.keda,
    azurerm_role_assignment.spn_dns_contributor,
    azurerm_role_assignment.spn_identity_operator,
    azurerm_role_assignment.spn_metrics_publisher,
    azurerm_role_assignment.spn_network_contributor,
    azurerm_role_assignment.spn_vm_contributor,
    azurerm_role_assignment.terraform_cluster_admin,
    azurerm_role_assignment.terraform_cluster_user
  ]
}

data azurerm_private_endpoint_connection api_server_endpoint {
  name                         = "kube-apiserver"
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group

  count                        = var.private_cluster_enabled ? 1 : 0
}

data azurerm_resources scale_sets {
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group
  type                         = "Microsoft.Compute/virtualMachineScaleSets"

  required_tags                = azurerm_kubernetes_cluster.aks.tags
}

# Export kube_config for kubectl
resource local_file kube_config {
  filename                     = var.kube_config_path
  content                      = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
}