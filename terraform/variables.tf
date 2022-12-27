variable application_name {
  description                  = "Value of 'application' resource tag"
  default                      = "Container Agents"
}

variable application_owner {
  description                  = "Value of 'owner' resource tag"
  default                      = "" # Empty string takes objectId of current user
}

variable configure_access_control {
  description                  = "Assumes the Terraform user is an owner of the subscription."
  default                      = false
  type                         = bool
}

variable container_image {
  default                      = null
}
variable container_registry_id {
  description                  = "Container Registry resource id"
  default                      = null
}

variable create_files_share {
  description                  = "Deploys files share (e.g. for agent diagnostics)"
  default                      = true
  type                         = bool
}

variable demo_viewers {
  description                  = "Object ID's of AAD groups/users to be granted reader access"
  default                      = []
  type                         = list
}

variable devops_org {
  description                  = "The Azure DevOps org to join self-hosted agents to (default pool: 'Default', see linux_pipeline_agent_pool/windows_pipeline_agent_pool)"
  default                      = null
}
variable devops_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization"
  default                      = null
}

variable environment_variables {
  type                         = map
  default                      = {}  
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

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map

  default                      = {
  }  
} 

variable user_assigned_identity_id {
  description                  = "User-assigned Managed Identity resource id"
  default                      = ""
}