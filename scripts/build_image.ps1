#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Builds a container image

.EXAMPLE
    ./build_image.ps1 -Local
.EXAMPLE
    ./build_image.ps1 -DevContainer
#> 
#Requires -Version 7.2
[CmdLetBinding(DefaultParameterSetName='LocalBuild')]
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="ubuntu-dev-tools",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Repository="pipelineagent",

    [parameter(Mandatory=$false,ParameterSetName='LocalBuild')]
    [switch]
    $Local=$false,

    [parameter(Mandatory=$false,ParameterSetName='LocalBuild')]
    [switch]
    $DevContainer=$false,

    [parameter(Mandatory=$false,ParameterSetName='AcrBuild')]
    [switch]
    $Acr=$false,

    [parameter(Mandatory=$true,ParameterSetName='AcrBuild')]
    [parameter(Mandatory=$false)]
    [string]
    $Registry,

    [parameter(Mandatory=$false)]
    [string]
    $Tag="scripted",

    [parameter(Mandatory=$false,ParameterSetName='LocalBuild')]
    [switch]
    $Scan=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

try {
    $imageDirectory = Join-Path (Split-Path $PSScriptRoot) images $ImageName
    $dockerFile = Join-Path $imageDirectory Dockerfile
    if (Test-Path $dockerFile) {
        Write-Verbose "Using ${dockerFile}"
    } else {
        Write-Warning "${dockerFile} does not exist"
        exit
    }
    Push-Location $imageDirectory

    if ($Local) {
        # Local build
        Start-ContainerEngine
        docker build -t ${Repository}/${ImageName}:${ImageName} .  
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }

        $Tags = @('docker','latest',$Tag,(Get-Date).ToString("yyyyMMdd"))
        foreach ($individualTag in $Tags) {
            docker tag ${Repository}/${ImageName}:${ImageName} "${Repository}/${ImageName}:${individualTag}"
            if ($Registry) {
                docker tag ${Repository}/${ImageName}:${ImageName} ${Registry}/${Repository}/${ImageName}:${individualTag}
            }
        }
        if ($Scan) {
            docker scan $ImageName --accept-license
        }
        docker images --filter=reference="${Repository}/${ImageName}:*" --filter=reference="${Registry}/${Repository}/${ImageName}:*"
    } 

    if ($DevContainer) {
        Start-ContainerEngine
        if ((Get-Command devcontainer)) {
            $devContainerConfigPath = Get-DevContainerConfigPath
            Write-Host "Building devcontainer using ${devContainerConfigPath}"
            devcontainer build --config $devContainerConfigPath
        } else {
            Write-Warning "devcontainer-cli is not installed"
            return
        }
    }

    if ($Acr) {
        # ACR build
        Login-Az -DisplayMessages
        az acr build -t ${Repository}/${ImageName}:acr `
                     -t ${Repository}/${ImageName}:latest `
                     -t ${Repository}/${ImageName}:${Tag} `
                     -t ${Repository}/${ImageName}:$((Get-Date).ToString("yyyyMMdd")) `
                     -r $Registry `
                     . `
                     --platform linux/amd64

        az acr repository show-tags -n $Registry `
                                    --repository ${Repository}/${ImageName} `
                                    --detail `
                                    --query "reverse(sort_by([].{name: '${Repository}/${ImageName}', tags: name, time: createdTime, digest: digest},&time))" `
                                    -o table 
    }
} finally {
    Pop-Location
}
