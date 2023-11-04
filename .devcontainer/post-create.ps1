#!/usr/bin/env pwsh
# Runs post create commands to prep Codespace for project

# This will be the location where we save a PowerShell profile
$profileTemplate = (Join-Path $PSScriptRoot profile.ps1)

# Link PowerShell Profile
if (!(Test-Path $Profile)) {
    Write-Host "Linking ${Profile} -> ${profileTemplate}"
    New-Item -ItemType symboliclink -Path $Profile -Target $profileTemplate -Force | Out-Null
}

if ($env:CODESPACES) {
    terraform -chdir="$(Join-Path (Split-Path $PSScriptRoot -Parent) terraform)" init -input=false
# } else {
    # git config core.autocrlf true
    # git config core.filemode true
    # git config --global core.editor "code --wait"
    # git config --global diff.tool vscode
    # git config --global difftool.vscode.cmd "code --wait --diff `$LOCAL `$REMOTE"
    # git config --global merge.tool vscode
    # git config --global mergetool.vscode.cmd "code --wait `$MERGED"
}