#!/usr/bin/env pwsh

#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="ubuntu",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Repository="pipelineagent",

    [parameter(Mandatory=$true,ParameterSetName='AcrBuild')]
    [parameter(Mandatory=$false,ParameterSetName='DockerBuild')]
    [string]
    $Registry,

    [parameter(Mandatory=$false)]
    [string[]]
    $Tags=@("latest"),

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
    Join-Path (Split-Path $(pwd)) images ubuntu | Push-Location

    if (!$Push) {
        # Local Docker build
        Start-Docker
        docker build --platform $Platform -t ${Repository}/${ImageName}:${ImageName} .  
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        foreach ($tag in $Tags) {
            docker tag ${Repository}/${ImageName}:${ImageName} "${Repository}/${ImageName}:${tag}"
            if ($Registry) {
                docker tag ${Repository}/${ImageName}:${ImageName} ${Registry}/${Repository}/${ImageName}:${tag}
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
                     -t ${Repository}/${ImageName}:${ImageName} `
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
