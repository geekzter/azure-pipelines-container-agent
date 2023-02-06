locals {
  projects_ids                 = zipmap(tolist(data.azuredevops_projects.projects.projects.*.name),  tolist(data.azuredevops_projects.projects.projects.*.project_id) )
}

resource azuredevops_agent_pool pool {
  name                         = var.pool_name
  auto_provision               = !var.authorize_queues
}

data azuredevops_projects projects {
  state                        = "wellFormed"
}

resource azuredevops_agent_queue queue {
  for_each                     = var.authorize_queues ? local.projects_ids : {}

  project_id                   = each.value
  agent_pool_id                = azuredevops_agent_pool.pool.id

  lifecycle {
    ignore_changes             = [
      agent_pool_id
    ]
  }
}

resource azuredevops_resource_authorization queue {
  for_each                     = var.authorize_queues ? local.projects_ids : {}

  project_id                   = each.value
  resource_id                  = azuredevops_agent_queue.queue[each.key].id
  type                         = "queue"
  authorized                   = true
}