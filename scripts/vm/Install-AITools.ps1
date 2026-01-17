#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install AI development tools on Ubuntu VM.

.DESCRIPTION
    This script installs AI development tools:
    - Installs Claude Code CLI globally via npm
    - Creates ~/.claude configuration directory
    - Configures telemetry off by default
    - Verifies installation
    - Optionally validates API key

    Prerequisites:
    - Node.js and npm installed
    - No root required (installs to user space)

.PARAMETER InstallClaudeCode
    If specified, installs Claude Code CLI.

.PARAMETER AnthropicAPIKey
    Optional Anthropic API key as SecureString. If provided, validates the key format.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./Install-AITools.ps1 -InstallClaudeCode
    Installs Claude Code CLI.

.EXAMPLE
    PS> $key = Read-Host -AsSecureString "API Key"
    PS> ./Install-AITools.ps1 -InstallClaudeCode -AnthropicAPIKey $key
    Installs Claude Code CLI and validates the API key.

.EXAMPLE
    PS> ./Install-AITools.ps1 -InstallClaudeCode -WhatIf
    Shows what would happen without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Node.js and npm installed

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Install Claude Code CLI")]
    [switch]$InstallClaudeCode,

    [Parameter(Mandatory = $false, HelpMessage = "Anthropic API Key")]
    [System.Security.SecureString]$AnthropicAPIKey
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

$script:ClaudeConfigDir = Join-Path $env:HOME '.claude'
$script:ClaudeSettingsFile = Join-Path $script:ClaudeConfigDir 'settings.json'

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
        'npm command'   = { Get-Command npm -ErrorAction SilentlyContinue }
        'node command'  = { Get-Command node -ErrorAction SilentlyContinue }
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

function ConvertFrom-SecureStringToPlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Security.SecureString]$SecureString
    )

    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
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
    Write-Log "Install Claude Code: $InstallClaudeCode" -Level Debug
    Write-Log "API Key provided: $($null -ne $AnthropicAPIKey)" -Level Debug

    Test-Prerequisites
}

function Install-ClaudeCodeCLI {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $claudeInfo = @{
        Installed = $false
        Version = $null
    }

    if ($PSCmdlet.ShouldProcess("Claude Code CLI", "Install globally via npm")) {
        Write-Log "Installing Claude Code CLI..." -Level Info

        try {
            # Install Claude Code globally
            Invoke-NativeCommand -Command 'npm' -Arguments @('install', '-g', '@anthropic-ai/claude-code')

            # Verify installation
            $version = Invoke-NativeCommand -Command 'claude' -Arguments @('--version') -PassThru -AllowFailure
            if ($LASTEXITCODE -eq 0 -and $version) {
                $claudeInfo.Version = $version.Trim()
                $claudeInfo.Installed = $true
                Write-Log "Claude Code CLI installed: $($claudeInfo.Version)" -Level Success
            }
            else {
                Write-Log "Claude Code CLI installation could not be verified" -Level Warning
            }
        }
        catch {
            Write-Log "Failed to install Claude Code CLI: $_" -Level Warning
        }
    }

    return $claudeInfo
}

function Initialize-ClaudeConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess($script:ClaudeConfigDir, "Create configuration directory")) {
        Write-Log "Creating Claude configuration directory..." -Level Info

        # Create config directory
        if (-not (Test-Path $script:ClaudeConfigDir)) {
            New-Item -ItemType Directory -Path $script:ClaudeConfigDir -Force | Out-Null
            Write-Log "Created directory: $($script:ClaudeConfigDir)" -Level Success
        }
        else {
            Write-Log "Directory already exists: $($script:ClaudeConfigDir)" -Level Info
        }

        # Set secure permissions
        if ($IsLinux) {
            Invoke-NativeCommand -Command 'chmod' -Arguments @('700', $script:ClaudeConfigDir) -AllowFailure
        }
    }
}

function Set-ClaudeTelemetryOff {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess($script:ClaudeSettingsFile, "Configure telemetry off")) {
        Write-Log "Configuring Claude Code telemetry..." -Level Info

        $settings = @{}

        # Load existing settings if present
        if (Test-Path $script:ClaudeSettingsFile) {
            try {
                $existingContent = Get-Content -Path $script:ClaudeSettingsFile -Raw
                $settings = $existingContent | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Log "Could not parse existing settings, creating new file" -Level Warning
                $settings = @{}
            }
        }

        # Set telemetry off
        $settings['telemetry'] = @{
            'enabled' = $false
        }

        # Write settings
        $settingsJson = $settings | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ClaudeSettingsFile -Value $settingsJson -Force

        # Set secure permissions
        if ($IsLinux) {
            Invoke-NativeCommand -Command 'chmod' -Arguments @('600', $script:ClaudeSettingsFile) -AllowFailure
        }

        Write-Log "Telemetry disabled in settings" -Level Success
    }
}

function Test-AnthropicAPIKey {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [System.Security.SecureString]$APIKey
    )

    $validation = @{
        Valid = $false
        Format = $false
        Message = ''
    }

    if ($PSCmdlet.ShouldProcess("API Key", "Validate format")) {
        Write-Log "Validating Anthropic API key..." -Level Info

        $plainKey = ConvertFrom-SecureStringToPlainText -SecureString $APIKey

        # Check format (Anthropic keys start with 'sk-ant-')
        if ($plainKey -match '^sk-ant-[a-zA-Z0-9-]+$') {
            $validation.Format = $true
            $validation.Message = "API key format is valid"
            Write-Log "API key format validation passed" -Level Success

            # Note: We don't make actual API calls to validate the key
            # as that would require making requests and potentially incur costs
            $validation.Valid = $true
        }
        else {
            $validation.Format = $false
            $validation.Message = "API key does not match expected format (should start with 'sk-ant-')"
            Write-Log "API key format validation failed" -Level Warning
        }
    }

    return $validation
}

function Get-InstallationVerification {
    [CmdletBinding()]
    param()

    Write-Log "Verifying AI tools installation..." -Level Info

    $verification = @{
        ClaudeCode = @{
            Installed = $false
            Version = $null
            ConfigExists = $false
            TelemetryDisabled = $false
        }
    }

    # Check Claude Code
    try {
        $version = Invoke-NativeCommand -Command 'claude' -Arguments @('--version') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0 -and $version) {
            $verification.ClaudeCode.Installed = $true
            $verification.ClaudeCode.Version = $version.Trim()
        }
    }
    catch {}

    # Check config directory
    $verification.ClaudeCode.ConfigExists = Test-Path $script:ClaudeConfigDir

    # Check telemetry setting
    if (Test-Path $script:ClaudeSettingsFile) {
        try {
            $settings = Get-Content -Path $script:ClaudeSettingsFile -Raw | ConvertFrom-Json
            if ($settings.telemetry -and $settings.telemetry.enabled -eq $false) {
                $verification.ClaudeCode.TelemetryDisabled = $true
            }
        }
        catch {}
    }

    return $verification
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date
    $apiKeyValidation = $null
    $claudeInstalled = $false

    if ($InstallClaudeCode) {
        # Install Claude Code CLI
        $claudeResult = Install-ClaudeCodeCLI
        $claudeInstalled = $claudeResult.Installed

        # Create config directory
        Initialize-ClaudeConfig

        # Configure telemetry off
        Set-ClaudeTelemetryOff
    }

    # Validate API key if provided
    if ($AnthropicAPIKey) {
        $apiKeyValidation = Test-AnthropicAPIKey -APIKey $AnthropicAPIKey
    }

    # Get final verification
    $verification = Get-InstallationVerification

    $endTime = Get-Date
    $duration = $endTime - $startTime

    $success = (-not $InstallClaudeCode) -or $verification.ClaudeCode.Installed

    [PSCustomObject]@{
        Success              = $success
        ClaudeCodeInstalled  = $verification.ClaudeCode.Installed
        ClaudeCodeVersion    = $verification.ClaudeCode.Version
        ConfigDirCreated     = $verification.ClaudeCode.ConfigExists
        TelemetryDisabled    = $verification.ClaudeCode.TelemetryDisabled
        APIKeyValidation     = $apiKeyValidation
        Duration             = $duration
        Timestamp            = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    Write-Log "" -Level Info
    Write-Log "=== AI Tools Installation Summary ===" -Level Info

    if ($InstallClaudeCode) {
        Write-Log "Claude Code CLI: $(if ($Result.ClaudeCodeInstalled) { $Result.ClaudeCodeVersion } else { 'Not installed' })" -Level Info
        Write-Log "Config directory: $(if ($Result.ConfigDirCreated) { 'Created' } else { 'Not created' })" -Level Info
        Write-Log "Telemetry: $(if ($Result.TelemetryDisabled) { 'Disabled' } else { 'Enabled' })" -Level Info
    }
    else {
        Write-Log "No AI tools installation requested" -Level Info
    }

    if ($Result.APIKeyValidation) {
        Write-Log "API Key: $(if ($Result.APIKeyValidation.Valid) { 'Valid format' } else { 'Invalid format' })" -Level Info
    }

    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "AI tools setup completed successfully" -Level Success
    }
    else {
        Write-Log "AI tools setup completed with errors" -Level Warning
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
