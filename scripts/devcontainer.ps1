#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Creates a local devcontainer

.EXAMPLE
    ./devcontainer.ps1 -Build
.EXAMPLE
    ./devcontainer.ps1 -Open
#> 
#Requires -Version 7.2
[CmdLetBinding(DefaultParameterSetName='LocalBuild')]
param ( 
    [parameter(Mandatory=$false)]
    [switch]
    $BuildOnly=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

# Push-Location (Split-Path $PSScriptRoot -Parent)
if (!(Get-Command devcontainer)) {
    Write-Warning "devcontainer-cli is not installed"
    return
}

Start-ContainerEngine
$devContainerConfigPath = Get-DevContainerConfigPath

Write-Host "Building devcontainer using ${devContainerConfigPath}"
devcontainer build --config $devContainerConfigPath

if (!$BuildOnly) {
    Write-Host "Open devcontainer using ${devContainerConfigPath}"
    devcontainer open (Split-Path $PSScriptRoot -Parent) --config $devContainerConfigPath
}
