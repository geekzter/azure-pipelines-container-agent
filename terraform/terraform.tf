terraform {
  required_providers {
    azapi = {
      source                   = "azure/azapi"
      version                  = "~> 1.1"
    }    
    azurerm                    = "~> 3.37"
    # http                       = "~> 2.2"
    # local                      = "~> 2.1"
    # null                       = "~> 3.1"
    random                     = "~> 3.4"
    # time                       = "~> 0.7"
  }
  required_version             = "~> 1.3"
}

provider azurerm {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data azurerm_client_config default {}
data azurerm_subscription default {}