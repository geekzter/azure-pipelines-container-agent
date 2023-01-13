terraform {
  required_providers {
    azapi                      = {
      source                   = "azure/azapi"
      version                  = "~> 1.1"
    }    
    # azuredevops = {
    #   source                   = "microsoft/azuredevops"
    #   version                  = "~> 0.3"
    # }
    azurerm                    = "~> 3.37"
    random                     = "~> 3.4"
    time                       = "~> 0.9"
  }
  required_version             = "~> 1.3"
}

# provider azuredevops {
#   features {
#     org_service_url            = var.devops_url
#     personal_access_token      = var.devops_pat
#   }
# }
provider azurerm {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # skip_provider_registration   = true
}

data azurerm_client_config default {}
data azurerm_subscription default {}