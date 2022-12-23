function Start-Docker () {
    Get-Process docker -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id | Set-Variable dockerProcessId

    if ($dockerProcessId) {
        Write-Host "Docker already running (pid: ${dockerProcessId})"
        return
    }
    
    if (!(Get-Command docker)) {
        Write-Warning "Docker is not installed"
        return
    }

    Write-Host "Starting Docker..."
    if ($IsLinux) {
        sudo service docker start
    }
    if ($IsMacos) {
        open -a docker
    }
    if ($IsWindows) {
        start docker
    }
    
    Write-Host "Waiting for Docker to complete startup" -NoNewline
    do {
        Start-Sleep -Milliseconds 250
        Write-Host "." -NoNewline
    } while (!$(docker stats --no-stream 2>$null))
    Write-Host "✓"
}