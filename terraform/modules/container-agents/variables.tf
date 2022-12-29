variable container_image {}
variable container_registry_id {}
variable devops_pat {}
variable devops_url {}
variable diagnostics_storage_share_key {}
variable diagnostics_storage_share_name {}
variable diagnostics_share_name {}
variable environment_variables {
    type = map
}
variable location {}
variable log_analytics_workspace_resource_id {}
variable pipeline_agent_cpu {
    type = number
}
variable pipeline_agent_memory {
    type = number
}
variable pipeline_agent_number_max {
    type = number
}
variable pipeline_agent_number_min {
    type = number
}
variable pipeline_agent_pool_id {}
variable pipeline_agent_pool_name {}
variable pipeline_agent_run_once {
  type = bool
}
variable pipeline_agent_version_id {}
variable resource_group_id {}
variable resource_group_name {}
variable suffix {}
variable tags {
  type = map
}
variable user_assigned_identity_id {}
