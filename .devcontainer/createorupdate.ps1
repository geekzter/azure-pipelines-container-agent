#!/usr/bin/env pwsh
# Runs post create commands to prep Codespace for project

# This will be the location where we save a PowerShell profile
$profileTemplate = (Join-Path $PSScriptRoot profile.ps1)

# Link PowerShell Profile
if (!(Test-Path $Profile)) {
    New-Item -ItemType symboliclink -Path $Profile -Target $profileTemplate -Force | Select-Object -ExpandProperty Name
}
