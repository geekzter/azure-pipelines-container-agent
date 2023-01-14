variable address_space {}
variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map
} 
variable deploy_bastion {
  type                         = bool
}
variable diagnostics_storage_id {}
variable gateway_type {
  type                         = string
  validation {
    condition                  = var.gateway_type == "Firewall" || var.gateway_type == "NATGateway" || var.gateway_type == "None"
    error_message              = "The gateway_type must be 'Firewall', 'NATGateway' or 'None'"
  }
}
variable location {}
variable log_analytics_workspace_resource_id {}
variable resource_group_name {}
variable tags {
  type                         = map
}