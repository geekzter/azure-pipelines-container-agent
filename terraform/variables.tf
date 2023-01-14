variable address_space {
  default                      = "10.201.0.0/22"
}

variable agent_identity_resource_id {
  description                  = "Resource id of pre-created User-assigned Managed Identity used to access Container Registry"
  default                      = ""
}

variable application_name {
  description                  = "Value of 'application' resource tag"
  default                      = "Container Agents"
}

variable application_owner {
  description                  = "Value of 'owner' resource tag"
  default                      = "" # Empty string takes objectId of current user
}

variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map

  default                      = {}  
} 

variable configure_access_control {
  description                  = "Assumes the Terraform user is an owner of the subscription."
  default                      = true
  type                         = bool
}

variable container_registry_id {
  description                  = "Container Registry resource id"
  default                      = null
}
variable container_repository {
  default                      = "pipelineagent/ubuntu"
}

variable create_files_share {
  description                  = "Deploys files share (e.g. for agent diagnostics)"
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

variable devops_url {
  description                  = "The Azure DevOps organization url to join self-hosted agents to (default pool: 'Default', see linux_pipeline_agent_pool/windows_pipeline_agent_pool)"
}
variable devops_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization. Requires Agent Pools read & manage scope."
}

variable environment_variables {
  type                         = map
  default                      = {}  
} 

variable gateway_type {
  type                         = string
  default                      = "None"
  validation {
    condition                  = var.gateway_type == "Firewall" || var.gateway_type == "NATGateway" || var.gateway_type == "None"
    error_message              = "The gateway_type must be 'Firewall', 'NATGateway' or 'None'"
  }
}

variable github_repo_access_token {
  description                  = "A GitHib Personal Access Token to access the Dockerfile"
  default                      = null
}

variable kube_config_path {
  description                  = "Path to the kube config file (e.g. ~/.kube/config)"
  default                      = ""
}

variable kubernetes_version {
  default                      = ""
}

variable kubernetes_node_size {
  default                      = "Standard_B4ms"
}
variable location {
  default                      = "centralus"
}

variable log_analytics_workspace_resource_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
}

variable pipeline_agent_diagnostics {
  description                  = "Turn on diagnostics for the pipeline agent (Agent.Diagnostic)"
  type                         = bool
  default                      = false
}

variable pipeline_agent_cpu {
  type                         = number
  default                      = 0.5
}
variable pipeline_agent_memory {
  type                         = number
  default                      = 1.0
}

variable pipeline_agent_number_max {
  type                         = number
  default                      = 10
}
variable pipeline_agent_number_min {
  type                         = number
  default                      = 1
}

variable pipeline_agent_pool_id {
  type                         = number
  default                      = 1
}

variable pipeline_agent_pool_name {
  default                      = "Default"
}

variable pipeline_agent_run_once {
  type                         = bool
  default                      = false
}

variable pipeline_agent_version_id {
  # https://api.github.com/repos/microsoft/azure-pipelines-agent/releases
  default                      = "latest"
}

variable resource_prefix {
  description                  = "The prefix to put at the of resource names created"
  default                      = "pipelines"
}
variable resource_suffix {
  description                  = "The suffix to put at the of resource names created"
  default                      = "" # Empty string triggers a random suffix
}

variable repository {
  description                  = "The value for the 'repository' resource tag"
  default                      = "azure-pipelines-container-agent"
}

variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
}

variable service_connection_id {
  description                  = "The Azure DevOps Service Connection GUID to join the scale set agents"
  default                      = ""
}

variable service_connection_project {
  description                  = "The Azure DevOps project where the Service Connection GUID to join the scale set agents resides"
  default                      = ""
}

variable ssh_public_key_file {
  type                         = string
  default                      = "~/.ssh/id_rsa.pub"
}

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map

  default                      = {
  }  
} 
