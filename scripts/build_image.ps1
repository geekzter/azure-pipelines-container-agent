#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)

Join-Path (Split-Path $(pwd)) images ubuntu | Push-Location

Start-Docker
docker build --platform linux/amd64 -t dockeragent:latest .  

Pop-Location