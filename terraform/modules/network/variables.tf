variable address_space {}
variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map
} 
variable deploy_bastion {
  type                         = bool
}
variable deploy_firewall {
  type                         = bool
}
variable diagnostics_storage_id {}
variable firewall_sku_tier {}
variable location {}
variable log_analytics_workspace_resource_id {}
variable resource_group_name {}
variable tags {
  type                         = map
}