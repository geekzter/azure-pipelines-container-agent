variable admin_object_ids {
  type        = list(string)
}
variable admin_username {}
variable configure_access_control {
  type        = bool
}
variable dns_prefix {}
variable enable_keda {
  type        = bool
}
variable enable_node_public_ip {
  type        = bool
}
variable kube_config_path {}
variable kubernetes_version {}
variable local_account_disabled {
  type        = bool
}
variable location {}
variable log_analytics_workspace_id {}
variable node_min_count {
  type        = number
}
variable node_max_count {
  type        = number
}
variable node_size {}
variable node_subnet_id {}
variable network_plugin {}
variable network_policy {}
variable network_outbound_type {}
variable peer_network_id {}
variable private_cluster_enabled {
  type        = bool
}
variable resource_group_id {}
variable tags {
  type        = map
}
variable user_assigned_identity_id {}
variable user_assigned_identity_is_precreated {
  type        = bool
}
