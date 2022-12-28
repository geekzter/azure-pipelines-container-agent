terraform {
  required_providers {
    azapi = {
      source                   = "azure/azapi"
      version                  = "~> 1.1"
    }    
    # azuredevops = {
    #   source                   = "microsoft/azuredevops"
    #   version                  = "~> 0.3"
    # }
    azurerm                    = "~> 3.37"
    # http                       = "~> 2.2"
    # local                      = "~> 2.1"
    # null                       = "~> 3.1"
    random                     = "~> 3.4"
    time                       = "~> 0.9"
  }
  required_version             = "~> 1.3"
}

# provider azuredevops {
#   features {
#     org_service_url            = "https://dev.azure.com/${var.devops_org}"
#     personal_access_token      = var.devops_provisioning_pat
#   }
# }
provider azurerm {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data azurerm_client_config default {}
data azurerm_subscription default {}