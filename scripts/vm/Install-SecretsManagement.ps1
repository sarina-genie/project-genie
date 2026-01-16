#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install SOPS and Age for secrets management on Ubuntu VM.

.DESCRIPTION
    This script installs secrets management tools:
    - Installs Age encryption tool (from apt or GitHub releases)
    - Installs SOPS (Secrets OPerationS) from GitHub releases
    - Verifies installations
    - Optionally generates an Age key pair
    - Configures SOPS_AGE_KEY_FILE environment variable

    Prerequisites:
    - Ubuntu Linux operating system
    - Root/sudo privileges (for /usr/local/bin installation)

.PARAMETER AgeVersion
    The version of Age to install. Default is "1.2.0".

.PARAMETER SOPSVersion
    The version of SOPS to install. Default is "3.9.0".

.PARAMETER GenerateKey
    If specified, generates a new Age key pair.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo pwsh ./Install-SecretsManagement.ps1
    Installs SOPS and Age with default versions.

.EXAMPLE
    PS> sudo pwsh ./Install-SecretsManagement.ps1 -GenerateKey
    Installs SOPS and Age, and generates a new Age key pair.

.EXAMPLE
    PS> sudo pwsh ./Install-SecretsManagement.ps1 -AgeVersion "1.2.0" -SOPSVersion "3.9.0" -GenerateKey
    Installs specific versions and generates keys.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Ubuntu Linux
    - Root privileges for /usr/local/bin

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Age version to install")]
    [ValidateNotNullOrEmpty()]
    [string]$AgeVersion = "1.2.0",

    [Parameter(Mandatory = $false, HelpMessage = "SOPS version to install")]
    [ValidateNotNullOrEmpty()]
    [string]$SOPSVersion = "3.9.0",

    [Parameter(Mandatory = $false, HelpMessage = "Generate Age key pair")]
    [switch]$GenerateKey
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

# Get the actual user's home directory (not root's when using sudo)
$script:ActualUser = if ($env:SUDO_USER) { $env:SUDO_USER } else { $env:USER }
$script:ActualHome = if ($env:SUDO_USER) { "/home/$env:SUDO_USER" } else { $env:HOME }
$script:SOPSAgeDir = Join-Path $script:ActualHome '.config/sops/age'
$script:AgeKeyFile = Join-Path $script:SOPSAgeDir 'keys.txt'
$script:BashrcPath = Join-Path $script:ActualHome '.bashrc'

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

function Get-SystemArchitecture {
    [CmdletBinding()]
    param()

    $arch = Invoke-NativeCommand -Command 'uname' -Arguments @('-m') -PassThru
    $arch = $arch.Trim()

    switch ($arch) {
        'x86_64'  { return 'amd64' }
        'aarch64' { return 'arm64' }
        'armv7l'  { return 'arm' }
        default   { return $arch }
    }
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug
    Write-Log "OS: $($PSVersionTable.OS)" -Level Debug
    Write-Log "Age Version: $AgeVersion" -Level Debug
    Write-Log "SOPS Version: $SOPSVersion" -Level Debug
    Write-Log "Generate Key: $GenerateKey" -Level Debug
    Write-Log "Actual User: $($script:ActualUser)" -Level Debug
    Write-Log "Actual Home: $($script:ActualHome)" -Level Debug

    Test-Prerequisites
}

function Install-Age {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Version
    )

    $ageInfo = @{
        Installed = $false
        Version = $null
        Source = $null
    }

    if ($PSCmdlet.ShouldProcess("Age v$Version", "Install encryption tool")) {
        Write-Log "Installing Age v$Version..." -Level Info

        # First try apt
        Write-Log "Attempting to install Age from apt..." -Level Info
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'age') -AllowFailure

        # Check if apt version is sufficient
        $installedVersion = Invoke-NativeCommand -Command 'age' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0 -and $installedVersion) {
            $ageInfo.Version = $installedVersion.Trim()
            $ageInfo.Installed = $true
            $ageInfo.Source = 'apt'
            Write-Log "Age installed from apt: $($ageInfo.Version)" -Level Success
        }
        else {
            # Install from GitHub releases
            Write-Log "Installing Age from GitHub releases..." -Level Info

            $arch = Get-SystemArchitecture
            $downloadUrl = "https://github.com/FiloSottile/age/releases/download/v$Version/age-v$Version-linux-$arch.tar.gz"
            $tempDir = "/tmp/age-install"

            try {
                # Create temp directory
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force
                }
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                # Download and extract
                $tarFile = Join-Path $tempDir "age.tar.gz"
                Invoke-NativeCommand -Command 'curl' -Arguments @('-fsSL', '-o', $tarFile, $downloadUrl)
                Invoke-NativeCommand -Command 'tar' -Arguments @('-xzf', $tarFile, '-C', $tempDir)

                # Install binaries
                $ageBin = Join-Path $tempDir "age/age"
                $ageKeygenBin = Join-Path $tempDir "age/age-keygen"

                if (Test-Path $ageBin) {
                    Copy-Item -Path $ageBin -Destination '/usr/local/bin/age' -Force
                    Invoke-NativeCommand -Command 'chmod' -Arguments @('+x', '/usr/local/bin/age')
                }
                if (Test-Path $ageKeygenBin) {
                    Copy-Item -Path $ageKeygenBin -Destination '/usr/local/bin/age-keygen' -Force
                    Invoke-NativeCommand -Command 'chmod' -Arguments @('+x', '/usr/local/bin/age-keygen')
                }

                # Verify
                $installedVersion = Invoke-NativeCommand -Command '/usr/local/bin/age' -Arguments @('--version') -PassThru
                $ageInfo.Version = $installedVersion.Trim()
                $ageInfo.Installed = $true
                $ageInfo.Source = 'github'
                Write-Log "Age installed from GitHub: $($ageInfo.Version)" -Level Success
            }
            finally {
                # Cleanup
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    return $ageInfo
}

function Install-SOPS {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Version
    )

    $sopsInfo = @{
        Installed = $false
        Version = $null
    }

    if ($PSCmdlet.ShouldProcess("SOPS v$Version", "Install from GitHub releases")) {
        Write-Log "Installing SOPS v$Version..." -Level Info

        $arch = Get-SystemArchitecture
        $downloadUrl = "https://github.com/getsops/sops/releases/download/v$Version/sops-v$Version.linux.$arch"
        $sopsPath = '/usr/local/bin/sops'

        try {
            # Download SOPS binary
            Invoke-NativeCommand -Command 'curl' -Arguments @('-fsSL', '-o', $sopsPath, $downloadUrl)

            # Make executable
            Invoke-NativeCommand -Command 'chmod' -Arguments @('+x', $sopsPath)

            # Verify installation
            $installedVersion = Invoke-NativeCommand -Command $sopsPath -Arguments @('--version') -PassThru
            $sopsInfo.Version = $installedVersion.Trim()
            $sopsInfo.Installed = $true
            Write-Log "SOPS installed: $($sopsInfo.Version)" -Level Success
        }
        catch {
            Write-Log "Failed to install SOPS: $_" -Level Warning
        }
    }

    return $sopsInfo
}

function New-AgeKeyPair {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $keyInfo = @{
        Generated = $false
        KeyFile = $null
        PublicKey = $null
    }

    if ($PSCmdlet.ShouldProcess($script:AgeKeyFile, "Generate Age key pair")) {
        Write-Log "Generating Age key pair..." -Level Info

        # Create config directory
        if (-not (Test-Path $script:SOPSAgeDir)) {
            New-Item -ItemType Directory -Path $script:SOPSAgeDir -Force | Out-Null
            Write-Log "Created directory: $($script:SOPSAgeDir)" -Level Info
        }

        # Generate key pair
        $ageKeygen = Get-Command 'age-keygen' -ErrorAction SilentlyContinue
        if (-not $ageKeygen) {
            $ageKeygen = '/usr/local/bin/age-keygen'
        }
        else {
            $ageKeygen = $ageKeygen.Source
        }

        $keyOutput = Invoke-NativeCommand -Command $ageKeygen -Arguments @('-o', $script:AgeKeyFile) -PassThru

        # Set secure permissions on key file
        Invoke-NativeCommand -Command 'chmod' -Arguments @('600', $script:AgeKeyFile)

        # Set ownership to actual user (not root)
        if ($script:ActualUser -ne 'root') {
            Invoke-NativeCommand -Command 'chown' -Arguments @('-R', "$($script:ActualUser):$($script:ActualUser)", (Split-Path $script:SOPSAgeDir -Parent))
        }

        $keyInfo.Generated = $true
        $keyInfo.KeyFile = $script:AgeKeyFile

        # Extract public key
        if (Test-Path $script:AgeKeyFile) {
            $keyContent = Get-Content -Path $script:AgeKeyFile
            $publicKeyLine = $keyContent | Where-Object { $_ -match '^# public key: ' }
            if ($publicKeyLine) {
                $keyInfo.PublicKey = ($publicKeyLine -replace '^# public key: ', '').Trim()
            }
        }

        Write-Log "Age key pair generated" -Level Success
        Write-Log "Key file: $($script:AgeKeyFile)" -Level Info
        if ($keyInfo.PublicKey) {
            Write-Log "Public key: $($keyInfo.PublicKey)" -Level Info
        }
    }

    return $keyInfo
}

function Add-SOPSEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess($script:BashrcPath, "Add SOPS_AGE_KEY_FILE environment variable")) {
        Write-Log "Adding SOPS_AGE_KEY_FILE to .bashrc..." -Level Info

        $exportLine = "export SOPS_AGE_KEY_FILE=`"$($script:AgeKeyFile)`""

        # Check if already present
        $bashrcContent = ''
        if (Test-Path $script:BashrcPath) {
            $bashrcContent = Get-Content -Path $script:BashrcPath -Raw
        }

        if ($bashrcContent -notmatch 'SOPS_AGE_KEY_FILE') {
            # Add to .bashrc
            $newContent = @"

# SOPS Age key file configuration
$exportLine
"@
            Add-Content -Path $script:BashrcPath -Value $newContent

            # Set ownership
            if ($script:ActualUser -ne 'root') {
                Invoke-NativeCommand -Command 'chown' -Arguments @("$($script:ActualUser):$($script:ActualUser)", $script:BashrcPath)
            }

            Write-Log "SOPS_AGE_KEY_FILE added to .bashrc" -Level Success
        }
        else {
            Write-Log "SOPS_AGE_KEY_FILE already configured in .bashrc" -Level Info
        }
    }
}

function Get-VerificationSummary {
    [CmdletBinding()]
    param()

    Write-Log "Verifying installations..." -Level Info

    $summary = @{
        Age = @{ Installed = $false; Version = $null }
        SOPS = @{ Installed = $false; Version = $null }
        KeyFile = @{ Exists = $false; Path = $null }
        EnvVar = @{ Configured = $false }
    }

    # Check Age
    try {
        $agePath = Get-Command 'age' -ErrorAction SilentlyContinue
        if ($agePath) {
            $version = Invoke-NativeCommand -Command 'age' -Arguments @('--version') -PassThru -AllowFailure
            if ($LASTEXITCODE -eq 0) {
                $summary.Age.Installed = $true
                $summary.Age.Version = $version.Trim()
            }
        }
    }
    catch {}

    # Check SOPS
    try {
        $sopsPath = Get-Command 'sops' -ErrorAction SilentlyContinue
        if ($sopsPath) {
            $version = Invoke-NativeCommand -Command 'sops' -Arguments @('--version') -PassThru -AllowFailure
            if ($LASTEXITCODE -eq 0) {
                $summary.SOPS.Installed = $true
                $summary.SOPS.Version = $version.Trim()
            }
        }
    }
    catch {}

    # Check key file
    if (Test-Path $script:AgeKeyFile) {
        $summary.KeyFile.Exists = $true
        $summary.KeyFile.Path = $script:AgeKeyFile
    }

    # Check environment variable in bashrc
    if (Test-Path $script:BashrcPath) {
        $bashrcContent = Get-Content -Path $script:BashrcPath -Raw
        if ($bashrcContent -match 'SOPS_AGE_KEY_FILE') {
            $summary.EnvVar.Configured = $true
        }
    }

    return $summary
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date

    # Install Age
    $ageResult = Install-Age -Version $AgeVersion

    # Install SOPS
    $sopsResult = Install-SOPS -Version $SOPSVersion

    # Generate key pair if requested
    $keyResult = @{ Generated = $false; KeyFile = $null; PublicKey = $null }
    if ($GenerateKey) {
        $keyResult = New-AgeKeyPair

        # Add environment variable
        if ($keyResult.Generated) {
            Add-SOPSEnvironmentVariable
        }
    }

    # Get verification summary
    $verification = Get-VerificationSummary

    $endTime = Get-Date
    $duration = $endTime - $startTime

    $success = $verification.Age.Installed -and $verification.SOPS.Installed

    [PSCustomObject]@{
        Success           = $success
        AgeInstalled      = $verification.Age.Installed
        AgeVersion        = $verification.Age.Version
        AgeSource         = $ageResult.Source
        SOPSInstalled     = $verification.SOPS.Installed
        SOPSVersion       = $verification.SOPS.Version
        KeyGenerated      = $keyResult.Generated
        KeyFile           = $keyResult.KeyFile
        PublicKey         = $keyResult.PublicKey
        EnvVarConfigured  = $verification.EnvVar.Configured
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
    Write-Log "=== Secrets Management Installation Summary ===" -Level Info
    Write-Log "Age: $(if ($Result.AgeInstalled) { "$($Result.AgeVersion) (from $($Result.AgeSource))" } else { 'Not installed' })" -Level Info
    Write-Log "SOPS: $(if ($Result.SOPSInstalled) { $Result.SOPSVersion } else { 'Not installed' })" -Level Info

    if ($GenerateKey) {
        Write-Log "Key generated: $(if ($Result.KeyGenerated) { 'Yes' } else { 'No' })" -Level Info
        if ($Result.KeyFile) {
            Write-Log "Key file: $($Result.KeyFile)" -Level Info
        }
        if ($Result.PublicKey) {
            Write-Log "Public key: $($Result.PublicKey)" -Level Info
        }
        Write-Log "SOPS_AGE_KEY_FILE configured: $(if ($Result.EnvVarConfigured) { 'Yes' } else { 'No' })" -Level Info
    }

    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "Secrets management tools installation completed successfully" -Level Success
        if ($GenerateKey -and $Result.KeyGenerated) {
            Write-Log "NOTE: Run 'source ~/.bashrc' or start a new shell to use SOPS_AGE_KEY_FILE" -Level Warning
        }
    }
    else {
        Write-Log "Secrets management tools installation completed with errors" -Level Warning
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
