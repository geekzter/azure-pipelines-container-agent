# Azure Pipeline Agent Container App
This repo contains an __experiment__ to run [Azure Pipeline Agents](https://learn.microsoft.com/azure/devops/pipelines/agents/docker?view=azure-devops) in [Azure Container Apps](https://azure.microsoft.com/products/container-apps). For __production__ use, consider [Scale set agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) ([sample repo](https://github.com/geekzter/azure-pipeline-agents)).

Features (see limitations below):
- [KEDA Azure Pipelines scaler](https://keda.sh/docs/scalers/azure-pipelines/)
- Diagnostics logs captured on [Azure Files](https://azure.microsoft.com/en-us/products/storage/files/)
- Ubuntu based image with core set of tools: Azure CLI, Helm, Kubectl, Packer, PowerShell, Terraform ([`Dockerfile`](./images/ubuntu/Dockerfile))

![](visuals/overview.png) 

## Instructions

### Local setup
- You'll need the [Azure CLI](http://aka.ms/azure-cli), Docker, [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) and [Terraform](https://developer.hashicorp.com/terraform/downloads)
- You can use an existing Azure Container Registry (if shared) or let Terraform create one. In case Terraform creates the ACR, there is no opportunity to build and push the container image to the ACR before the Container App will use it.   
Either let Terraform fail -> build & push the image -> retry Terraform apply, or pre-create the ACR. In case you pre-create the ACR, you also need to pre-create a User-assigned Managed Identity with `AcrPull` role on the ACR.
- Build and push the agent container image using either the [`build_image.ps1`](./scripts/build_image.ps1) script
- Create a `config.auto.tfvars` file ([example](./terraform/config.auto.tfvars.example)) in the terraform directory, and use it to set the following variables:   
`agent_identity_resource_id`  
`container_registry_id`   
`devops_pat`   
`devops_url`   
- Provision infrastructure by running `terraform apply`

### Pipeline setup
- You'll need an existing Azure Container Registry (the assumption is this is a shared component and the Service Connection identity does not have the Azure `Owner` role required to configure RBAC)
- Create an User-assigned Managed Identity with `AcrPush` role on the Azure Container Registry
- Create an [Terraform azurerm backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- Create a Docker Registry Service Connection to the ACR
- Create a Personal Access Token with Agent Pools read & manage scope
- Create a variable group `build-container-agent-image` with the following variable:   `containerRegistry` (ACR Service Connection)
- Create a variable group `pipeline-container-agents` with the following variables:   
`subscriptionConnection` (Azure Service Connection)  
`TF_STATE_CONTAINER_NAME` ([Terraform azurerm backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm) storage container)   
`TF_STATE_RESOURCE_GROUP_NAME` ([Terraform azurerm backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm) storage account resource group)  
`TF_STATE_STORAGE_ACCOUNT_NAME` ([Terraform azurerm backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm) storage account)  
`TF_VAR_agent_identity_resource_id`  
`TF_VAR_container_registry_id`  
`TF_VAR_devops_pat`
- Use the [`deploy-container-agents.yml`](./pipelines/deploy-container-agents.yml) to build the agent container image, provision infrastructure and run a test job on a newly created agent.
### Testing
- Use the [`image-info.yml`](./pipelines/image-info.yml) pipeline to test the agents. You can override the `numberOfJobs` parameter to test elasticity

## Limitations
- `ScaledJob` is [not supported](https://github.com/microsoft/azure-container-apps/issues/24) in Azure Container Apps. The KEDA Pipelines scaler requires this to indicate a long-running process needs to finish before a pod instance is terminated. This means pipeline jobs can get terminated prematurely.
- Azure Container Apps have a [maximum replica limit of 30](https://learn.microsoft.com/en-us/azure/container-apps/scale-app). Hence a Container App pool can at most have 30 agents.
- Azure Container Apps do not yet support [volume mount options](https://github.com/microsoft/azure-container-apps/issues/520). Option `nobrl` is required to guarantee logs are persisted. Hence agents that are configured to terminate after a job run may not have logs fully captured.
- The image is not a general purpose image that works with all of the [Azure Pipeline Tasks](https://github.com/microsoft/azure-pipelines-tasks)