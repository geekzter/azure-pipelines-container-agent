#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Builds the container agent image

.EXAMPLE
    ./build_image.ps1
.EXAMPLE
    ./build_image.ps1 -Push
#> 
#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="ubuntu-dev-tools",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Repository="pipelineagent",

    [parameter(Mandatory=$true,ParameterSetName='AcrBuild')]
    [parameter(Mandatory=$false)]
    [string]
    $Registry,

    [parameter(Mandatory=$false)]
    [string]
    $Tag="scripted",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Platform="linux/amd64",

    [parameter(Mandatory=$false,ParameterSetName='AcrBuild')]
    [switch]
    $Push=$false,

    [parameter(Mandatory=$false,ParameterSetName='DockerBuild')]
    [switch]
    $Scan=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

try {
    $imageDirectory = Join-Path (Split-Path $(pwd)) images $ImageName
    $dockerFile = Join-Path $imageDirectory Dockerfile
    if (Test-Path $dockerFile) {
        Write-Verbose "Using ${dockerFile}"
    } else {
        Write-Warning "${dockerFile} does not exist"
        exit
    }
    Push-Location $imageDirectory

    if (!$Push) {
        # Local build
        Start-ContainerEngine
        docker build --platform $Platform -t ${Repository}/${ImageName}:${ImageName} .  
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
    } else {
        # ACR build
        Login-Az -DisplayMessages
        az acr build -t ${Repository}/${ImageName}:acr `
                     -t ${Repository}/${ImageName}:latest `
                     -t ${Repository}/${ImageName}:${Tag} `
                     -t ${Repository}/${ImageName}:$((Get-Date).ToString("yyyyMMdd")) `
                     -r $Registry `
                     . `
                     --platform $Platform

        az acr repository show-tags -n $Registry `
                                    --repository ${Repository}/${ImageName} `
                                    --detail `
                                    --query "reverse(sort_by([].{name: '${Repository}/${ImageName}', tags: name, time: createdTime, digest: digest},&time))" `
                                    -o table 
    }
} finally {
    Pop-Location
}
