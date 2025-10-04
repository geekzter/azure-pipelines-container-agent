variable address_space {}
variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map
} 
variable configure_diagnostics_storage {
  type                         = bool
}
variable container_registry_id {}
variable deploy_bastion {
  type                         = bool
}
variable diagnostics_storage_id {}
variable gateway_type {
  type                         = string
  validation {
    condition                  = var.gateway_type == "Firewall" || var.gateway_type == "NATGateway" || var.gateway_type == "NoGateway"
    error_message              = "The gateway_type must be 'Firewall', 'NATGateway' or 'NoGateway'"
  }
}
variable ip_tags {
  type                         = map
}
variable location {}
variable log_analytics_workspace_resource_id {}
variable peer_network_id {}
variable peer_network_has_gateway {}
variable resource_group_name {}
variable tags {
  type                         = map
}
