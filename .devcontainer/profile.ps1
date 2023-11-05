#!/usr/bin/env pwsh
#Requires -Version 7.2

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

Write-Verbose "Importing functions..."
$functionsPath = "${HOME}/src/bootstrap-os/common/functions"
Get-ChildItem $functionsPath -filter "*.ps1" | ForEach-Object {
    if ($printMessages) {
        Write-Host "$($_.FullName) : loaded"
    }
    . $_.FullName
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

if (Get-Command Add-PoshGitToProfile -ErrorAction SilentlyContinue) {
    Add-PoshGitToProfile 3>$null
}

Set-Location $repoDirectory/scripts
Write-Host ""
"Review the README at $($PSStyle.Bold){0}$($PSStyle.Reset) on how to build container images and provision container agents"  -f "${repoDirectory}/README.md" | Write-Host
Write-Host ""
