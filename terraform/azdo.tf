data external azdo_token {
  program                      = [
    "az", "account", "get-access-token", 
    "--resource", "499b84ac-1321-427f-aa17-267ca6975798", # Azure DevOps
    "--query","{accessToken:accessToken}",
    "-o","json"
  ]
}

# data azuredevops_client_config current {}

locals {
  azdo_token                   = var.devops_url != null && var.devops_url != "" && var.devops_pat != null && var.devops_pat != "" ? var.devops_pat : data.external.azdo_token.result.accessToken
  devops_url                   = replace(var.devops_url,"/\\/$/","")
}