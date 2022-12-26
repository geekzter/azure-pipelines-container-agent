# Azure Pipeline Agent Container App
This repo contains an experiment to run [Azure Pipeline Agents](https://learn.microsoft.com/azure/devops/pipelines/agents/docker?view=azure-devops) in [Azure Container Apps](https://azure.microsoft.com/products/container-apps). For production use, consider [Scale set agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) ([sample repo](https://github.com/geekzter/azure-pipeline-agents)).

Features (see limitations below):
- [KEDA Azure Pipelines scaler](https://keda.sh/docs/scalers/azure-pipelines/)
- Diagnostics logs captured on [Azure Files](https://azure.microsoft.com/en-us/products/storage/files/)

## Limitations
- `ScaledJob` is [not supported](https://github.com/microsoft/azure-container-apps/issues/24) in Azure Container Apps. The KEDA Pipelines scaler requires this to indicate a long-running process needs to finish before a pod instance is terminated. This means pipeline jobs can get terminated prematurely.
- Azure Container Apps have a [maximum replica limit of 30](https://learn.microsoft.com/en-us/azure/container-apps/scale-app). Hence a Container App pool can at most have 30 agents.
- Azure Container Apps do not yet support [volume mount options](https://github.com/microsoft/azure-container-apps/issues/520). Option `nobrl` is required to persist logs. Hence agents that are configured to terminate after a job run may not have logs fully captured.