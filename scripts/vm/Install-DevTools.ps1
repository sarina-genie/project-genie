#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install development runtimes and tools on Ubuntu VM.

.DESCRIPTION
    This script installs development runtimes on Ubuntu:
    - Verifies Python 3 installation
    - Installs python3-pip and python3-venv
    - Adds NodeSource repository for Node.js
    - Installs Node.js LTS version
    - Optionally installs uv (fast Python package manager)
    - Verifies all installations

    Prerequisites:
    - Ubuntu Linux operating system
    - Root/sudo privileges (for system packages)

.PARAMETER NodeVersion
    The major version of Node.js to install. Default is "20" (LTS).

.PARAMETER InstallUV
    If specified, installs uv (fast Python package manager).

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo pwsh ./Install-DevTools.ps1
    Installs Node.js 20 and Python tools with default settings.

.EXAMPLE
    PS> sudo pwsh ./Install-DevTools.ps1 -NodeVersion "22" -InstallUV
    Installs Node.js 22 and uv package manager.

.EXAMPLE
    PS> sudo pwsh ./Install-DevTools.ps1 -WhatIf
    Shows what would happen without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Ubuntu Linux
    - Root privileges for system packages

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Node.js major version to install")]
    [ValidateSet("18", "20", "22")]
    [string]$NodeVersion = "20",

    [Parameter(Mandatory = $false, HelpMessage = "Install uv Python package manager")]
    [switch]$InstallUV
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

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
    Write-Log "Node.js Version: $NodeVersion" -Level Debug
    Write-Log "Install UV: $InstallUV" -Level Debug

    Test-Prerequisites
}

function Test-PythonInstallation {
    [CmdletBinding()]
    param()

    Write-Log "Verifying Python 3 installation..." -Level Info

    $pythonInfo = @{
        Installed = $false
        Version = $null
        Path = $null
    }

    try {
        $pythonPath = Invoke-NativeCommand -Command 'which' -Arguments @('python3') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0 -and $pythonPath) {
            $pythonInfo.Path = $pythonPath.Trim()
            $pythonVersion = Invoke-NativeCommand -Command 'python3' -Arguments @('--version') -PassThru
            $pythonInfo.Version = $pythonVersion.Trim()
            $pythonInfo.Installed = $true
            Write-Log "Python 3 found: $($pythonInfo.Version) at $($pythonInfo.Path)" -Level Success
        }
        else {
            Write-Log "Python 3 not found, will attempt to install" -Level Warning
        }
    }
    catch {
        Write-Log "Error checking Python: $_" -Level Warning
    }

    return $pythonInfo
}

function Install-PythonTools {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $installed = @()

    if ($PSCmdlet.ShouldProcess("Python development packages", "Install pip and venv")) {
        Write-Log "Installing Python development packages..." -Level Info

        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')

        # Install Python 3 if not present
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'python3') -AllowFailure

        # Install pip and venv
        $packages = @('python3-pip', 'python3-venv', 'python3-dev')
        foreach ($package in $packages) {
            try {
                Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', $package)
                $installed += $package
                Write-Log "Installed $package" -Level Success
            }
            catch {
                Write-Log "Failed to install $package`: $_" -Level Warning
            }
        }
    }

    return $installed
}

function Install-NodeJS {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Version
    )

    $nodeInfo = @{
        Installed = $false
        Version = $null
        NpmVersion = $null
    }

    if ($PSCmdlet.ShouldProcess("Node.js $Version", "Install from NodeSource")) {
        Write-Log "Installing Node.js $Version..." -Level Info

        # Install prerequisites
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'ca-certificates', 'curl', 'gnupg')

        # Create keyrings directory
        $keyringDir = '/etc/apt/keyrings'
        if (-not (Test-Path $keyringDir)) {
            New-Item -ItemType Directory -Path $keyringDir -Force | Out-Null
        }

        # Download and add NodeSource GPG key
        Write-Log "Adding NodeSource GPG key..." -Level Info
        $keyUrl = 'https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key'
        $keyPath = '/etc/apt/keyrings/nodesource.gpg'

        Invoke-NativeCommand -Command 'bash' -Arguments @('-c', "curl -fsSL $keyUrl | gpg --dearmor -o $keyPath")

        # Add NodeSource repository
        Write-Log "Adding NodeSource repository..." -Level Info
        $repoLine = "deb [signed-by=$keyPath] https://deb.nodesource.com/node_$Version.x nodistro main"
        Set-Content -Path '/etc/apt/sources.list.d/nodesource.list' -Value $repoLine -Force

        # Update and install
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'nodejs')

        # Verify installation
        try {
            $nodeVersion = Invoke-NativeCommand -Command 'node' -Arguments @('--version') -PassThru
            $nodeInfo.Version = $nodeVersion.Trim()

            $npmVersion = Invoke-NativeCommand -Command 'npm' -Arguments @('--version') -PassThru
            $nodeInfo.NpmVersion = $npmVersion.Trim()

            $nodeInfo.Installed = $true
            Write-Log "Node.js installed: $($nodeInfo.Version)" -Level Success
            Write-Log "npm installed: $($nodeInfo.NpmVersion)" -Level Success
        }
        catch {
            Write-Log "Failed to verify Node.js installation: $_" -Level Warning
        }
    }

    return $nodeInfo
}

function Install-UV {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $uvInfo = @{
        Installed = $false
        Version = $null
    }

    if ($PSCmdlet.ShouldProcess("uv", "Install Python package manager")) {
        Write-Log "Installing uv..." -Level Info

        try {
            # Install using the official installer
            Invoke-NativeCommand -Command 'bash' -Arguments @('-c', 'curl -LsSf https://astral.sh/uv/install.sh | sh')

            # Add to PATH for verification (installer adds to .bashrc/.profile)
            $uvPath = "/root/.local/bin/uv"
            if (-not (Test-Path $uvPath)) {
                $uvPath = "$env:HOME/.local/bin/uv"
            }

            if (Test-Path $uvPath) {
                $uvVersion = Invoke-NativeCommand -Command $uvPath -Arguments @('--version') -PassThru -AllowFailure
                if ($uvVersion) {
                    $uvInfo.Version = $uvVersion.Trim()
                    $uvInfo.Installed = $true
                    Write-Log "uv installed: $($uvInfo.Version)" -Level Success
                }
            }
            else {
                # Try from PATH
                $uvVersion = Invoke-NativeCommand -Command 'bash' -Arguments @('-c', 'source ~/.bashrc 2>/dev/null; uv --version') -PassThru -AllowFailure
                if ($LASTEXITCODE -eq 0 -and $uvVersion) {
                    $uvInfo.Version = $uvVersion.Trim()
                    $uvInfo.Installed = $true
                    Write-Log "uv installed: $($uvInfo.Version)" -Level Success
                }
            }
        }
        catch {
            Write-Log "Failed to install uv: $_" -Level Warning
        }
    }

    return $uvInfo
}

function Get-VerificationSummary {
    [CmdletBinding()]
    param()

    Write-Log "Verifying all installations..." -Level Info

    $summary = @{
        Python = @{ Installed = $false; Version = $null }
        Pip = @{ Installed = $false; Version = $null }
        Node = @{ Installed = $false; Version = $null }
        Npm = @{ Installed = $false; Version = $null }
        UV = @{ Installed = $false; Version = $null }
    }

    # Python
    try {
        $version = Invoke-NativeCommand -Command 'python3' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0) {
            $summary.Python.Installed = $true
            $summary.Python.Version = $version.Trim()
        }
    }
    catch {}

    # Pip
    try {
        $version = Invoke-NativeCommand -Command 'pip3' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0) {
            $summary.Pip.Installed = $true
            $summary.Pip.Version = ($version -split ' ')[1]
        }
    }
    catch {}

    # Node
    try {
        $version = Invoke-NativeCommand -Command 'node' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0) {
            $summary.Node.Installed = $true
            $summary.Node.Version = $version.Trim()
        }
    }
    catch {}

    # npm
    try {
        $version = Invoke-NativeCommand -Command 'npm' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0) {
            $summary.Npm.Installed = $true
            $summary.Npm.Version = $version.Trim()
        }
    }
    catch {}

    # UV (if installed)
    if ($InstallUV) {
        try {
            $uvPath = "/root/.local/bin/uv"
            if (-not (Test-Path $uvPath)) {
                $uvPath = "$env:HOME/.local/bin/uv"
            }
            if (Test-Path $uvPath) {
                $version = Invoke-NativeCommand -Command $uvPath -Arguments @('--version') -PassThru -AllowFailure
                if ($LASTEXITCODE -eq 0) {
                    $summary.UV.Installed = $true
                    $summary.UV.Version = $version.Trim()
                }
            }
        }
        catch {}
    }

    return $summary
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date

    # Verify/install Python
    $pythonCheck = Test-PythonInstallation
    $pythonPackages = Install-PythonTools

    # Install Node.js
    $nodeInfo = Install-NodeJS -Version $NodeVersion

    # Optionally install UV
    $uvInfo = @{ Installed = $false; Version = $null }
    if ($InstallUV) {
        $uvInfo = Install-UV
    }

    # Get final verification
    $verification = Get-VerificationSummary

    $endTime = Get-Date
    $duration = $endTime - $startTime

    $success = $verification.Python.Installed -and $verification.Node.Installed

    [PSCustomObject]@{
        Success           = $success
        PythonVersion     = $verification.Python.Version
        PipVersion        = $verification.Pip.Version
        NodeVersion       = $verification.Node.Version
        NpmVersion        = $verification.Npm.Version
        UVVersion         = $verification.UV.Version
        UVInstalled       = $verification.UV.Installed
        PythonPackages    = $pythonPackages
        Duration          = $duration
        Timestamp         = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    Write-Log "" -Level Info
    Write-Log "=== Development Tools Installation Summary ===" -Level Info
    Write-Log "Python: $($Result.PythonVersion)" -Level Info
    Write-Log "pip: $($Result.PipVersion)" -Level Info
    Write-Log "Node.js: $($Result.NodeVersion)" -Level Info
    Write-Log "npm: $($Result.NpmVersion)" -Level Info
    if ($InstallUV) {
        Write-Log "uv: $(if ($Result.UVInstalled) { $Result.UVVersion } else { 'Not installed' })" -Level Info
    }
    Write-Log "Python packages installed: $($Result.PythonPackages -join ', ')" -Level Info
    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "Development tools installation completed successfully" -Level Success
    }
    else {
        Write-Log "Development tools installation completed with errors" -Level Warning
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
