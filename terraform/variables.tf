variable aca_agent_pool_name {
  description                  = "Name of the agent pool to create for Azure Container Apps (ACA) agents"
  default                      = "Default"
  nullable                     = true
}

variable address_space {
  default                      = "10.201.0.0/22"
  nullable                     = false
}

variable agent_identity_resource_id {
  description                  = "Resource id of pre-created User-assigned Managed Identity used to access Container Registry"
  default                      = ""
  nullable                     = true
}

variable aks_agent_pool_name {
  description                  = "Name of the agent pool to create for Azure Kubernetes Service (AKS) agents"
  default                      = "Default"
  nullable                     = true
}

variable aks_private_cluster_enabled {
  default                      = false
  type                         = bool
}

variable application_name {
  description                  = "Value of 'application' resource tag"
  default                      = "Container Agents"
  nullable                     = false
}

variable application_owner {
  description                  = "Value of 'owner' resource tag"
  default                      = "" # Empty string takes objectId of current user
  nullable                     = false
}

variable authorize_agent_queues {
  default                      = true
  type                         = bool
}

variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map

  default                      = {}  
  nullable                     = false
} 

variable configure_access_control {
  description                  = "Assumes the Terraform user is an owner of the subscription."
  default                      = true
  type                         = bool
}

variable container_registry_id {
  description                  = "Container Registry resource id"
  default                      = null
  nullable                     = true
}
variable container_repository {
  default                      = "pipelineagent/ubuntu"
  nullable                     = false
}

variable create_agent_pools {
  description                  = "Create specific agent pools for ACA & AKS"
  default                      = true
  type                         = bool
}

variable create_files_share {
  description                  = "Deploys files share (e.g. for agent diagnostics)"
  default                      = true
  type                         = bool
}

variable create_portal_dashboard {
  default                      = true
  type                         = bool
}

variable deploy_aks {
  description                  = "Deploys AKS"
  default                      = false
  type                         = bool
}

variable deploy_bastion {
  description                  = "Deploys managed bastion host"
  default                      = false
  type                         = bool
}

variable deploy_container_app {
  description                  = "Deploys Container App"
  default                      = true
  type                         = bool
}

variable deploy_network {
  description                  = "Deploys Virtual Network"
  default                      = true
  type                         = bool
}

variable devops_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization. Requires Agent Pools read & manage scope."
  nullable                     = false
}
variable devops_project {
  description                  = "The Azure DevOps project to authorize agent pools for. Requires 'Read & execute' permission on Build (queue a build) scope)"
  default                      = null
  nullable                     = true
}
variable devops_url {
  description                  = "The Azure DevOps organization url to join self-hosted agents to (default pool: 'Default', see linux_pipeline_agent_pool/windows_pipeline_agent_pool)"
  nullable                     = false
}

variable environment_variables {
  type                         = map
  default                      = {}  
  nullable                     = false
} 

variable gateway_type {
  type                         = string
  default                      = "NoGateway"
  nullable                     = false
  validation {
    condition                  = var.gateway_type == "Firewall" || var.gateway_type == "NATGateway" || var.gateway_type == "NoGateway"
    error_message              = "The gateway_type must be 'Firewall', 'NATGateway' or 'NoGateway'"
  }
}

variable github_repo_access_token {
  description                  = "A GitHib Personal Access Token to access the Dockerfile"
  default                      = null
}

variable kube_config_path {
  description                  = "Path to the kube config file (e.g. ~/.kube/config)"
  default                      = ""
  nullable                     = true
}
variable kubernetes_local_account_disabled {
  default                      = false
  type                         = bool
}
variable kubernetes_node_min_count {
  default                      = 1
  type                         = number
}
variable kubernetes_node_max_count {
  default                      = 10
  type                         = number
}
variable kubernetes_node_size {
  default                      = "Standard_B4ms"
  nullable                     = false
}
variable kubernetes_version {
  default                      = ""
  nullable                     = true
}

variable location {
  default                      = "centralus"
  nullable                     = false
}

variable log_analytics_workspace_resource_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
  nullable                     = true
}

variable peer_network_has_gateway {
  type                         = bool
  default                      = false
}

variable peer_network_id {
  description                  = "Virtual network to be peered with. This is usefull to run Terraform from and be able to access a private API server."
  default                      = ""
  nullable                     = true
}

variable pipeline_agent_diagnostics {
  description                  = "Turn on diagnostics for the pipeline agent (Agent.Diagnostic)"
  type                         = bool
  default                      = false
}

variable pipeline_agent_cpu {
  type                         = number
  default                      = 0.5
  nullable                     = false
}
variable pipeline_agent_memory {
  type                         = number
  default                      = 1.0
  nullable                     = false
}

variable pipeline_agent_number_max {
  type                         = number
  default                      = 10
  nullable                     = false
}
variable pipeline_agent_number_min {
  type                         = number
  default                      = 1
  nullable                     = false
}

variable pipeline_agent_run_once {
  type                         = bool
  default                      = false
}

variable pipeline_agent_version_id {
  # https://api.github.com/repos/microsoft/azure-pipelines-agent/releases
  default                      = "latest"
  nullable                     = false
}

variable resource_prefix {
  description                  = "The prefix to put at the end of resource names created"
  default                      = "pipelines"
  nullable                     = false
}
variable resource_project {
  description                  = "The middle part of resource names created"
  default                      = "container-agents"
  nullable                     = true
}
variable resource_suffix {
  description                  = "The suffix to put at the start of resource names created"
  default                      = "" # Empty string triggers a random suffix
  nullable                     = true
}

variable repository {
  description                  = "The value for the 'repository' resource tag"
  default                      = "azure-pipelines-container-agent"
  nullable                     = false
}

variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
  nullable                     = true
}

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map
  nullable                     = false

  default                      = {
  }  
} 
