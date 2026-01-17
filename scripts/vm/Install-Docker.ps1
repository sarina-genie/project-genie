#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install Docker Engine on Ubuntu VM.

.DESCRIPTION
    This script installs Docker Engine and related components on Ubuntu:
    - Removes old Docker packages if present
    - Adds Docker official GPG key
    - Adds Docker apt repository
    - Installs docker-ce, docker-ce-cli, containerd.io
    - Installs docker-compose-plugin and docker-buildx-plugin
    - Adds current user to docker group
    - Enables and starts Docker service
    - Verifies installation with docker version and hello-world

    Prerequisites:
    - Ubuntu Linux operating system
    - Root/sudo privileges

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo pwsh ./Install-Docker.ps1
    Installs Docker Engine with all components.

.EXAMPLE
    PS> sudo pwsh ./Install-Docker.ps1 -WhatIf
    Shows what would happen without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Ubuntu Linux
    - Root privileges

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param()

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

# Docker packages to remove (old versions)
$script:OldDockerPackages = @(
    'docker.io'
    'docker-doc'
    'docker-compose'
    'docker-compose-v2'
    'podman-docker'
    'containerd'
    'runc'
)

# Docker packages to install
$script:DockerPackages = @(
    'docker-ce'
    'docker-ce-cli'
    'containerd.io'
    'docker-compose-plugin'
    'docker-buildx-plugin'
)

#endregion Configuration

#region Helper Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Info'    { Write-Host $Message -ForegroundColor Cyan }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Host $Message -ForegroundColor Red }
        'Success' { Write-Host $Message -ForegroundColor Green }
        'Debug'   { Write-Debug $Message }
    }

    if ($script:LogFile) {
        $logDir = Split-Path $script:LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Test-IsElevated {
    [CmdletBinding()]
    param()

    if ($IsLinux -or $IsMacOS) {
        return (id -u) -eq 0
    }
    return $false
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$AllowFailure
    )

    Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug

    $result = & $Command @Arguments 2>&1

    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        throw "Command failed with exit code $LASTEXITCODE`: $result"
    }

    if ($PassThru) {
        return $result
    }
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-Log "Checking prerequisites..." -Level Debug

    $prerequisites = [ordered]@{
        'PowerShell 7+' = { $PSVersionTable.PSVersion.Major -ge 7 }
        'Linux OS'      = { $IsLinux }
        'Root Privileges' = { Test-IsElevated }
        'apt command'   = { Get-Command apt -ErrorAction SilentlyContinue }
        'curl command'  = { Get-Command curl -ErrorAction SilentlyContinue }
    }

    $failed = @()
    foreach ($check in $prerequisites.GetEnumerator()) {
        try {
            $result = & $check.Value
            if (-not $result) {
                $failed += $check.Key
            }
        }
        catch {
            $failed += $check.Key
        }
    }

    if ($failed.Count -gt 0) {
        throw "Prerequisites not met: $($failed -join ', ')"
    }

    Write-Log "All prerequisites verified" -Level Success
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug
    Write-Log "OS: $($PSVersionTable.OS)" -Level Debug

    Test-Prerequisites
}

function Remove-OldDocker {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("Old Docker packages", "Remove conflicting packages")) {
        Write-Log "Removing old Docker packages..." -Level Info

        foreach ($package in $script:OldDockerPackages) {
            Invoke-NativeCommand -Command 'apt-get' -Arguments @('remove', '-y', '-qq', $package) -AllowFailure
        }

        Write-Log "Old Docker packages removed" -Level Success
    }
}

function Add-DockerGPGKey {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $keyringDir = '/etc/apt/keyrings'
    $keyringPath = "$keyringDir/docker.gpg"

    if ($PSCmdlet.ShouldProcess($keyringPath, "Add Docker GPG key")) {
        Write-Log "Adding Docker GPG key..." -Level Info

        # Create keyrings directory
        if (-not (Test-Path $keyringDir)) {
            New-Item -ItemType Directory -Path $keyringDir -Force | Out-Null
        }

        # Download and add GPG key
        $gpgUrl = 'https://download.docker.com/linux/ubuntu/gpg'
        Invoke-NativeCommand -Command 'curl' -Arguments @('-fsSL', $gpgUrl, '-o', '/tmp/docker.gpg.key')
        Invoke-NativeCommand -Command 'gpg' -Arguments @('--dearmor', '-o', $keyringPath, '/tmp/docker.gpg.key') -AllowFailure

        # If dearmor failed, try direct download of binary key
        if (-not (Test-Path $keyringPath)) {
            Invoke-NativeCommand -Command 'bash' -Arguments @('-c', "curl -fsSL $gpgUrl | gpg --dearmor -o $keyringPath")
        }

        Invoke-NativeCommand -Command 'chmod' -Arguments @('a+r', $keyringPath)

        Write-Log "Docker GPG key added" -Level Success
    }
}

function Add-DockerRepository {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $repoFile = '/etc/apt/sources.list.d/docker.list'

    if ($PSCmdlet.ShouldProcess($repoFile, "Add Docker repository")) {
        Write-Log "Adding Docker repository..." -Level Info

        # Get Ubuntu codename
        $codename = Invoke-NativeCommand -Command 'bash' -Arguments @('-c', '. /etc/os-release && echo $VERSION_CODENAME') -PassThru
        $codename = $codename.Trim()

        # Get architecture
        $arch = Invoke-NativeCommand -Command 'dpkg' -Arguments @('--print-architecture') -PassThru
        $arch = $arch.Trim()

        $repoLine = "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"

        Set-Content -Path $repoFile -Value $repoLine -Force

        Write-Log "Docker repository added for $codename ($arch)" -Level Success

        # Update apt cache
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')
    }
}

function Install-DockerPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $installed = @()

    if ($PSCmdlet.ShouldProcess("Docker packages", "Install Docker Engine and plugins")) {
        Write-Log "Installing Docker packages..." -Level Info

        # Install all packages in one command
        $installArgs = @('install', '-y', '-qq') + $script:DockerPackages
        Invoke-NativeCommand -Command 'apt-get' -Arguments $installArgs

        $installed = $script:DockerPackages
        Write-Log "Docker packages installed" -Level Success
    }

    return $installed
}

function Add-UserToDockerGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Get the original user (not root when using sudo)
    $originalUser = $env:SUDO_USER
    if (-not $originalUser) {
        $originalUser = $env:USER
    }

    if ($originalUser -and $originalUser -ne 'root') {
        if ($PSCmdlet.ShouldProcess($originalUser, "Add user to docker group")) {
            Write-Log "Adding user '$originalUser' to docker group..." -Level Info

            Invoke-NativeCommand -Command 'usermod' -Arguments @('-aG', 'docker', $originalUser)

            Write-Log "User '$originalUser' added to docker group" -Level Success
            Write-Log "NOTE: User must log out and back in for group membership to take effect" -Level Warning
        }
        return $originalUser
    }

    return $null
}

function Enable-DockerService {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("docker.service", "Enable and start Docker service")) {
        Write-Log "Enabling Docker service..." -Level Info

        Invoke-NativeCommand -Command 'systemctl' -Arguments @('enable', 'docker')
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('start', 'docker')

        # Also enable containerd
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('enable', 'containerd')
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('start', 'containerd')

        Write-Log "Docker service enabled and started" -Level Success
    }
}

function Test-DockerInstallation {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $verification = @{
        DockerVersion = $null
        ComposeVersion = $null
        HelloWorldPassed = $false
    }

    if ($PSCmdlet.ShouldProcess("Docker installation", "Verify installation")) {
        Write-Log "Verifying Docker installation..." -Level Info

        # Get Docker version
        try {
            $dockerVersion = Invoke-NativeCommand -Command 'docker' -Arguments @('version', '--format', '{{.Server.Version}}') -PassThru
            $verification.DockerVersion = $dockerVersion.Trim()
            Write-Log "Docker version: $($verification.DockerVersion)" -Level Success
        }
        catch {
            Write-Log "Failed to get Docker version: $_" -Level Warning
        }

        # Get Compose version
        try {
            $composeVersion = Invoke-NativeCommand -Command 'docker' -Arguments @('compose', 'version', '--short') -PassThru
            $verification.ComposeVersion = $composeVersion.Trim()
            Write-Log "Docker Compose version: $($verification.ComposeVersion)" -Level Success
        }
        catch {
            Write-Log "Failed to get Docker Compose version: $_" -Level Warning
        }

        # Run hello-world
        try {
            Write-Log "Running hello-world container..." -Level Info
            Invoke-NativeCommand -Command 'docker' -Arguments @('run', '--rm', 'hello-world')
            $verification.HelloWorldPassed = $true
            Write-Log "hello-world test passed" -Level Success
        }
        catch {
            Write-Log "hello-world test failed: $_" -Level Warning
        }
    }

    return $verification
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date

    # Remove old Docker packages
    Remove-OldDocker

    # Add Docker GPG key
    Add-DockerGPGKey

    # Add Docker repository
    Add-DockerRepository

    # Install Docker packages
    $installedPackages = Install-DockerPackages

    # Add user to docker group
    $addedUser = Add-UserToDockerGroup

    # Enable Docker service
    Enable-DockerService

    # Verify installation
    $verification = Test-DockerInstallation

    $endTime = Get-Date
    $duration = $endTime - $startTime

    [PSCustomObject]@{
        Success          = ($verification.DockerVersion -ne $null)
        InstalledPackages = $installedPackages
        DockerVersion    = $verification.DockerVersion
        ComposeVersion   = $verification.ComposeVersion
        HelloWorldPassed = $verification.HelloWorldPassed
        UserAddedToGroup = $addedUser
        Duration         = $duration
        Timestamp        = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    Write-Log "" -Level Info
    Write-Log "=== Docker Installation Summary ===" -Level Info
    Write-Log "Docker Version: $($Result.DockerVersion)" -Level Info
    Write-Log "Compose Version: $($Result.ComposeVersion)" -Level Info
    Write-Log "Packages installed: $($Result.InstalledPackages.Count)" -Level Info
    Write-Log "Hello-world test: $(if ($Result.HelloWorldPassed) { 'Passed' } else { 'Failed' })" -Level Info
    if ($Result.UserAddedToGroup) {
        Write-Log "User added to docker group: $($Result.UserAddedToGroup)" -Level Info
    }
    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "Docker installation completed successfully" -Level Success
    }
    else {
        Write-Log "Docker installation completed with errors" -Level Warning
    }
}

#endregion Main Functions

#region Main Execution

try {
    Initialize-Script

    $result = Invoke-MainLogic

    Complete-Script -Result $result

    return $result
}
catch {
    Write-Log "Script failed: $_" -Level Error
    Write-Log $_.ScriptStackTrace -Level Debug

    return [PSCustomObject]@{
        Success   = $false
        Error     = $_.Exception.Message
        Timestamp = Get-Date
    }
}
finally {
    $ProgressPreference = 'Continue'
}

#endregion Main Execution
