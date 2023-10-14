#!/usr/bin/env pwsh
#Requires -Version 7.2

Write-Verbose "Importing functions..."
$functionsPath = "${HOME}/src/bootstrap-os/common/functions"
Get-ChildItem $functionsPath -filter "*.ps1" | ForEach-Object {
    if ($printMessages) {
        Write-Host "$($_.FullName) : loaded"
    }
    . $_.FullName
}

function global:Prompt {
    if ($GitPromptScriptBlock) {
        # Use Posh-Git: https://github.com/dahlbyk/posh-git/wiki/Customizing-Your-PowerShell-Prompt
        # Use ~ for home directory in prompt
        $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true 
        # Don't overwrite the title set in iTerm2/Windows Terminal
        $GitPromptSettings.WindowTitle = $null
        if ($env:CODESPACES -ieq "true") {
            $GitPromptSettings.DefaultPromptPrefix = "[${env:GITHUB_USER}@${env:CODESPACE_NAME}]: "
            $GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'            
        }
        $GitPromptSettings.DefaultPromptSuffix = "`$('#' * (`$nestedPromptLevel + 1)) "
        $prompt = (& $GitPromptScriptBlock)
    } else {
        $host.ui.rawui.WindowTitle = "PowerShell Core $($host.Version.ToString())"

        if ($executionContext.SessionState.Path.CurrentLocation.Path.StartsWith($home)) {
            $path = $executionContext.SessionState.Path.CurrentLocation.Path.Replace($home,"~")
        } else {
            $path = $executionContext.SessionState.Path.CurrentLocation.Path
        }

        $host.ui.rawui.WindowTitle += "$($executionContext.SessionState.Path.CurrentLocation.Path)"
        $branch = $(git rev-parse --abbrev-ref HEAD 2>$null)
        $prompt = $path
        if ($branch) {
            $prompt += ":$branch"
        }
        $host.ui.rawui.WindowTitle += " # "
        $prompt += "$('#' * ($nestedPromptLevel + 1)) ";
    }
    if ($prompt) { "$prompt" } else { " " }
}

$repoDirectory = (Split-Path (Split-Path (Get-Item $MyInvocation.MyCommand.Path).Target -Parent) -Parent)
$scriptDirectory = (Join-Path $repoDirectory "scripts")
$env:PATH += ":${scriptDirectory}"

# Making sure pwsh is the default shell for Terraform local-exec
$env:SHELL = (Get-Command pwsh).Source

# Set additional environment variables as Codespace secrets
# https://docs.github.com/en/codespaces/managing-your-codespaces/managing-encrypted-secrets-for-your-codespaces

# Show tmux sessions
if (Get-Command tmux -ErrorAction SilentlyContinue) {
    $tmuxSessions = $(tmux ls 2>/dev/null)
    if ($tmuxSessions) {
        Write-Host "Active tmux sessions:"
        $tmuxSessions
    }
}

Write-Host ""
Set-Location $repoDirectory/scripts
Write-Host "$($PSStyle.Bold)1)$($PSStyle.Reset) To prevent losing (or to reconnect to) a terminal session, type $($PSStyle.Bold)ct <terraform workspace>$($PSStyle.Reset)"
Write-Host "$($PSStyle.Bold)2)$($PSStyle.Reset) To provision infrastructure, run $($PSStyle.Bold)$repoDirectory/scripts/deploy.ps1 -Apply$($PSStyle.Reset)"
Write-Host "$($PSStyle.Bold)3)$($PSStyle.Reset) To destroy infrastructure, run $($PSStyle.Bold)$repoDirectory/scripts/deploy.ps1 -Destroy$($PSStyle.Reset)"
Write-Host ""
