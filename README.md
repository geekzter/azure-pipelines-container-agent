# Azure Pipeline Agent Container App
This repo contains an experiment to run [Azure Pipeline Agents](https://learn.microsoft.com/azure/devops/pipelines/agents/docker?view=azure-devops) in [Azure Container Apps](https://azure.microsoft.com/products/container-apps). For production use, consider [Scale set agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) ([sample repo](https://github.com/geekzter/azure-pipeline-agents)).

Features (see limitations below):
- [KEDA Azure Pipelines scaler](https://keda.sh/docs/scalers/azure-pipelines/)
- Diagnostics logs captured on [Azure Files](https://azure.microsoft.com/en-us/products/storage/files/)

## Instructions
- You'll need an existing Azure Container Registry (assumed shared so not provisioned by this repo)
- Build and push image using either the [`build-image.yml`](./pipelines/build-image.yml) pipeline or [`build_image.ps1`](./scripts/build_image.ps1) script
- You need to either pre-create an User-assigned Managed Identity with `AcrPull` role on the Azure Container Registry, or;   
Set `configure_access_control = true` in `config.auto.tfvars` ([example](./terraform/config.auto.tfvars.example), requires `Owner` role for Terraform)
- Provision infrastructure by running `terraform apply` or [`deploy.ps1`](./scripts/deploy.ps1) `-apply`
- Use to the [`image-info.yml`](./pipelines/image-info.yml) pipeline with `numberOfJobs` set to test elasticiy of the pool

## Limitations
- `ScaledJob` is [not supported](https://github.com/microsoft/azure-container-apps/issues/24) in Azure Container Apps. The KEDA Pipelines scaler requires this to indicate a long-running process needs to finish before a pod instance is terminated. This means pipeline jobs can get terminated prematurely.
- Azure Container Apps have a [maximum replica limit of 30](https://learn.microsoft.com/en-us/azure/container-apps/scale-app). Hence a Container App pool can at most have 30 agents.
- Azure Container Apps do not yet support [volume mount options](https://github.com/microsoft/azure-container-apps/issues/520). Option `nobrl` is required to persist logs. Hence agents that are configured to terminate after a job run may not have logs fully captured.
- The [`Dockerfile`](./images/ubuntu/Dockerfile) includes only a limited set of tools