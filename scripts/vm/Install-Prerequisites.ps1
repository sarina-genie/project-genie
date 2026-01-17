#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install base system packages on Ubuntu VM.

.DESCRIPTION
    This script installs essential and optional system packages on an Ubuntu VM:
    - Updates apt cache
    - Installs essential packages (curl, wget, git, jq, htop, tmux, vim, tree, ca-certificates, gnupg, apt-transport-https)
    - Installs optional tools (ripgrep, fd-find, bat, ncdu)
    - Cleans apt cache to reduce disk usage

    Prerequisites:
    - Ubuntu Linux operating system
    - Root/sudo privileges

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo pwsh ./Install-Prerequisites.ps1
    Installs all prerequisite packages on the system.

.EXAMPLE
    PS> sudo pwsh ./Install-Prerequisites.ps1 -WhatIf
    Shows what packages would be installed without making changes.

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

# Package definitions
$script:EssentialPackages = @(
    'curl'
    'wget'
    'git'
    'jq'
    'htop'
    'tmux'
    'vim'
    'tree'
    'ca-certificates'
    'gnupg'
    'apt-transport-https'
)

$script:OptionalPackages = @(
    'ripgrep'
    'fd-find'
    'bat'
    'ncdu'
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

function Update-AptCache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("apt cache", "Update package lists")) {
        Write-Log "Updating apt cache..." -Level Info
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')
        Write-Log "Apt cache updated" -Level Success
    }
}

function Install-EssentialPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $installed = @()
    $failed = @()

    Write-Log "Installing essential packages..." -Level Info

    foreach ($package in $script:EssentialPackages) {
        if ($PSCmdlet.ShouldProcess($package, "Install essential package")) {
            try {
                Write-Log "Installing $package..." -Level Info
                Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', $package)
                $installed += $package
                Write-Log "Installed $package" -Level Success
            }
            catch {
                Write-Log "Failed to install $package`: $_" -Level Warning
                $failed += $package
            }
        }
    }

    return @{
        Installed = $installed
        Failed = $failed
    }
}

function Install-OptionalPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $installed = @()
    $skipped = @()

    Write-Log "Installing optional packages..." -Level Info

    foreach ($package in $script:OptionalPackages) {
        if ($PSCmdlet.ShouldProcess($package, "Install optional package")) {
            try {
                Write-Log "Installing $package..." -Level Info
                Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', $package) -AllowFailure
                if ($LASTEXITCODE -eq 0) {
                    $installed += $package
                    Write-Log "Installed $package" -Level Success
                }
                else {
                    Write-Log "Package $package not available, skipping" -Level Warning
                    $skipped += $package
                }
            }
            catch {
                Write-Log "Failed to install optional package $package`: $_" -Level Warning
                $skipped += $package
            }
        }
    }

    return @{
        Installed = $installed
        Skipped = $skipped
    }
}

function Clear-AptCache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("apt cache", "Clean cached packages")) {
        Write-Log "Cleaning apt cache..." -Level Info
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('clean')
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('autoremove', '-y', '-qq')
        Write-Log "Apt cache cleaned" -Level Success
    }
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date

    # Update apt cache
    Update-AptCache

    # Install essential packages
    $essentialResult = Install-EssentialPackages

    # Install optional packages
    $optionalResult = Install-OptionalPackages

    # Clean up
    Clear-AptCache

    $endTime = Get-Date
    $duration = $endTime - $startTime

    [PSCustomObject]@{
        Success            = ($essentialResult.Failed.Count -eq 0)
        EssentialInstalled = $essentialResult.Installed
        EssentialFailed    = $essentialResult.Failed
        OptionalInstalled  = $optionalResult.Installed
        OptionalSkipped    = $optionalResult.Skipped
        Duration           = $duration
        Timestamp          = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    Write-Log "" -Level Info
    Write-Log "=== Installation Summary ===" -Level Info
    Write-Log "Essential packages installed: $($Result.EssentialInstalled.Count)" -Level Info
    Write-Log "Essential packages failed: $($Result.EssentialFailed.Count)" -Level Info
    Write-Log "Optional packages installed: $($Result.OptionalInstalled.Count)" -Level Info
    Write-Log "Optional packages skipped: $($Result.OptionalSkipped.Count)" -Level Info
    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "Script completed successfully" -Level Success
    }
    else {
        Write-Log "Script completed with errors" -Level Warning
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
