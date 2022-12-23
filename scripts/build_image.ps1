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
    $Repository="dockeragent",

    [parameter(Mandatory=$false)]
    [string]
    $Registry,

    [parameter(Mandatory=$false)]
    [string[]]
    $Tag=@("latest"),

    [parameter(Mandatory=$false)]
    [switch]
    $Scan=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

try {
    Join-Path (Split-Path $(pwd)) images ubuntu | Push-Location

    Start-Docker
    docker build --platform linux/amd64 -t ${Repository}/${ImageName} .  
    if ($Registry) {
        docker tag ${Repository}/${ImageName} "${Registry}/${Repository}/${ImageName}"
        # docker tag ${Repository}/${ImageName} "${Registry}/${ImageName}"
    }
    if ($Scan) {
        docker scan $ImageName --accept-license
    }
    docker images --filter=reference="${Repository}/$ImageName" --filter=reference="${Registry}/${Repository}/$ImageName"
} finally {
    Pop-Location
}
