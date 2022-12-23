#!/usr/bin/env pwsh

#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="dockeragent:latest",

    [parameter(Mandatory=$false)]
    [switch]
    $Scan=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

try {
    Join-Path (Split-Path $(pwd)) images ubuntu | Push-Location

    Start-Docker
    docker build --platform linux/amd64 -t $ImageName .  
    if ($Scan) {
        docker scan $ImageName --accept-license
    }
} finally {
    Pop-Location
}
