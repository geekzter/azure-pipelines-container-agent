terraform {
  backend "azurerm" {
    # resource_group_name        = "Automation"
    resource_group_name        = "ericvan-common"
    # storage_account_name       = "ewterraformstate"
    storage_account_name       = "ericvantfstore"
    container_name             = "pipelinecontaineragents" 
    key                        = "terraform.tfstate"
    sas_token                  = "sp=racwl&st=2022-12-24T16:38:42Z&se=2023-12-28T00:38:42Z&spr=https&sv=2021-06-08&sr=c&sig=4RagwYxH7lo4%2Fs8gUi104msV7KcxEXVGs9a2YJ3Dukw%3D"
  }
}
