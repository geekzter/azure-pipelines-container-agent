locals {
  projects_ids                 = zipmap(tolist(data.azuredevops_projects.all_projects.projects.*.name),  tolist(data.azuredevops_projects.all_projects.projects.*.project_id) )
}

resource azuredevops_agent_pool pool {
  name                         = var.pool_name
  auto_provision               = !var.authorize_all_projects
}

data azuredevops_projects all_projects {
  state                        = "wellFormed"
}
resource azuredevops_agent_queue all_project_queues {
  for_each                     = var.authorize_all_projects ? local.projects_ids : {}

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
  for_each                     = var.authorize_all_projects ? local.projects_ids : {}

  project_id                   = each.value
  resource_id                  = azuredevops_agent_queue.all_project_queues[each.key].id
  type                         = "queue"
  authorized                   = true
}

data azuredevops_project single_project {
  name                         = var.authorize_project

  count                        = !var.authorize_all_projects && var.authorize_project != null  && var.authorize_project != "" ? 1 : 0
}
data azuredevops_agent_queue single_project_queue {
  project_id                   = data.azuredevops_project.single_project.0.project_id
  name                         = azuredevops_agent_pool.pool.name

  count                        = !var.authorize_all_projects && var.authorize_project != null  && var.authorize_project != "" ? 1 : 0
}
# Requires 'Read & execute' permission on Build (queue a build) scope
resource azuredevops_resource_authorization single_project_queue {
  project_id                   = data.azuredevops_project.single_project.0.project_id
  resource_id                  = data.azuredevops_agent_queue.single_project_queue.0.id
  type                         = "queue"
  authorized                   = true

  count                        = !var.authorize_all_projects && var.authorize_project != null  && var.authorize_project != "" ? 1 : 0
}