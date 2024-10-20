terraform {
  required_providers {
    azapi                      = {
      source                   = "azure/azapi"
      version                  = "~> 1.9"
    }
    azuredevops                = {
      source                   = "microsoft/azuredevops"
      version                  = "~> 1.0"
    }
    azurerm                    = "~> 4.6"
    local                      = "~> 2.3"
    random                     = "~> 3.4"
    time                       = "~> 0.9"
  }
  required_version             = "~> 1.3"
}

provider azapi {}
provider azuredevops {
  org_service_url              = local.devops_url
}
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