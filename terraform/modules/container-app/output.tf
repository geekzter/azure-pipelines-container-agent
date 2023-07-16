output container_app_id {
  value       = var.container_app ? azapi_resource.agent_container_app.0.id : null
}
output container_app_name {
  value       = var.container_app ? azapi_resource.agent_container_app.0.name : null
}
output container_job_id {
  value       = var.container_job ? azapi_resource.agent_container_job.0.id : null
}
output container_job_name {
  value       = var.container_job ? azapi_resource.agent_container_job.0.name : null
}

output container_environment_id {
  value       = azapi_resource.agent_container_environment.id
}