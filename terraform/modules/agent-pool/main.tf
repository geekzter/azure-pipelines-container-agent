locals {
  projects_ids                 = zipmap(tolist(data.azuredevops_projects.all_projects.projects.*.name),  tolist(data.azuredevops_projects.all_projects.projects.*.project_id) )
}

resource azuredevops_agent_pool pool {
  name                         = var.pool_name
  auto_provision               = false

  lifecycle {
    ignore_changes             = [
      name
    ]
  }
}

data azuredevops_projects all_projects {
  state                        = "wellFormed"
}
resource azuredevops_agent_queue all_project_queues {
  for_each                     = var.create_queue_for_all_projects ? local.projects_ids : {}

  project_id                   = each.value
  agent_pool_id                = azuredevops_agent_pool.pool.id

  lifecycle {
    ignore_changes             = [
      agent_pool_id
    ]
  }
}
# Requires 'Read & execute' permission on Build (queue a build) scope
resource azuredevops_resource_authorization all_project_queues {
  for_each                     = var.create_queue_for_all_projects && var.authorize_queues ? local.projects_ids : {}

  project_id                   = each.value
  resource_id                  = azuredevops_agent_queue.all_project_queues[each.key].id
  type                         = "queue"
  authorized                   = true
}

data azuredevops_project single_project {
  name                         = var.create_queue_for_project

  count                        = !var.create_queue_for_all_projects && var.create_queue_for_project != null  && var.create_queue_for_project != "" ? 1 : 0
}
resource azuredevops_agent_queue single_project_queue {
  project_id                   = data.azuredevops_project.single_project.0.project_id
  agent_pool_id                = azuredevops_agent_pool.pool.id

  count                        = !var.create_queue_for_all_projects && var.create_queue_for_project != null  && var.create_queue_for_project != "" ? 1 : 0
}
# Requires 'Read & execute' permission on Build (queue a build) scope
resource azuredevops_resource_authorization single_project_queue {
  project_id                   = data.azuredevops_project.single_project.0.project_id
  resource_id                  = azuredevops_agent_queue.single_project_queue.0.id
  type                         = "queue"
  authorized                   = true

  count                        = !var.create_queue_for_all_projects && var.authorize_queues && var.create_queue_for_project != null  && var.create_queue_for_project != "" ? 1 : 0
}