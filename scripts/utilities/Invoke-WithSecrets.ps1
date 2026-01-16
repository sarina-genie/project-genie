#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Run a command with decrypted secrets from a SOPS-encrypted file.

.DESCRIPTION
    Securely executes commands with environment variables from encrypted secrets:
    - Verifies SOPS_AGE_KEY_FILE environment variable is set
    - Verifies the encrypted secrets file exists
    - Decrypts secrets using SOPS
    - Exports decrypted values as environment variables
    - Executes the specified command
    - Clears environment variables after execution

    This script does not require root privileges.

.PARAMETER Command
    The command and its arguments to execute.

.PARAMETER SecretsFile
    Path to the SOPS-encrypted secrets file. Defaults to ".env.enc" in current directory.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./Invoke-WithSecrets.ps1 -Command "python", "app.py"
    Runs python app.py with secrets from .env.enc

.EXAMPLE
    PS> ./Invoke-WithSecrets.ps1 -Command "npm", "run", "start" -SecretsFile "./secrets/prod.env.enc"
    Runs npm command with secrets from a custom file.

.EXAMPLE
    PS> ./Invoke-WithSecrets.ps1 -Command "env" -WhatIf
    Shows what secrets would be loaded without running the command.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - SOPS installed and in PATH
    - Age key file configured (SOPS_AGE_KEY_FILE)
    - Encrypted secrets file in SOPS-compatible format

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Command and arguments to execute")]
    [ValidateNotNullOrEmpty()]
    [string[]]$Command,

    [Parameter(Mandatory = $false, HelpMessage = "Path to encrypted secrets file")]
    [ValidateNotNullOrEmpty()]
    [string]$SecretsFile = ".env.enc"
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"
$script:LoadedSecrets = @()

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

function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-Log "Checking prerequisites..." -Level Debug

    $prerequisites = [ordered]@{
        'PowerShell 7+' = { $PSVersionTable.PSVersion.Major -ge 7 }
        'SOPS' = { Get-Command sops -ErrorAction SilentlyContinue }
        'SOPS_AGE_KEY_FILE set' = { -not [string]::IsNullOrEmpty($env:SOPS_AGE_KEY_FILE) }
        'Age key file exists' = {
            if ($env:SOPS_AGE_KEY_FILE) {
                Test-Path $env:SOPS_AGE_KEY_FILE
            } else {
                $false
            }
        }
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
        [hashtable]$Environment
    )

    Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug

    # Store original environment
    $originalEnv = @{}
    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $Environment[$key])
        }
    }

    try {
        $result = & $Command @Arguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($PassThru) {
            return @{
                Output = $result
                ExitCode = $exitCode
            }
        }
    }
    finally {
        # Restore original environment
        if ($Environment) {
            foreach ($key in $Environment.Keys) {
                if ($null -eq $originalEnv[$key]) {
                    [Environment]::SetEnvironmentVariable($key, $null)
                }
                else {
                    [Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
                }
            }
        }
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

    Test-Prerequisites
}

function Test-SecretsFile {
    [CmdletBinding()]
    param()

    # Resolve path (could be relative)
    $resolvedPath = if ([System.IO.Path]::IsPathRooted($SecretsFile)) {
        $SecretsFile
    }
    else {
        Join-Path (Get-Location) $SecretsFile
    }

    if (-not (Test-Path $resolvedPath)) {
        throw "Secrets file not found: $resolvedPath"
    }

    Write-Log "Secrets file found: $resolvedPath" -Level Debug
    return $resolvedPath
}

function Get-DecryptedSecrets {
    [CmdletBinding()]
    param(
        [string]$FilePath
    )

    Write-Log "Decrypting secrets from: $FilePath" -Level Info

    # Determine output format based on file extension
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    $outputFormat = switch ($extension) {
        '.json' { 'json' }
        '.yaml' { 'yaml' }
        '.yml'  { 'yaml' }
        default { 'dotenv' }  # .env, .enc, etc.
    }

    try {
        $decrypted = & sops --decrypt --output-type $outputFormat $FilePath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "SOPS decryption failed: $decrypted"
        }

        return @{
            Content = $decrypted
            Format = $outputFormat
        }
    }
    catch {
        throw "Failed to decrypt secrets: $_"
    }
}

function ConvertTo-EnvironmentVariables {
    [CmdletBinding()]
    param(
        [string]$Content,
        [string]$Format
    )

    $envVars = @{}

    switch ($Format) {
        'dotenv' {
            # Parse KEY=VALUE format
            $lines = $Content -split "`n"
            foreach ($line in $lines) {
                $line = $line.Trim()

                # Skip empty lines and comments
                if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
                    continue
                }

                # Parse KEY=VALUE
                if ($line -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()

                    # Remove quotes if present
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }

                    $envVars[$key] = $value
                }
            }
        }
        'json' {
            $json = $Content | ConvertFrom-Json -AsHashtable
            foreach ($key in $json.Keys) {
                $envVars[$key] = $json[$key].ToString()
            }
        }
        'yaml' {
            # Simple YAML parsing for flat key: value structures
            $lines = $Content -split "`n"
            foreach ($line in $lines) {
                $line = $line.Trim()

                if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
                    continue
                }

                if ($line -match '^([^:]+):\s*(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()

                    # Remove quotes if present
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }

                    $envVars[$key] = $value
                }
            }
        }
    }

    return $envVars
}

function Set-SecretEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [hashtable]$Secrets
    )

    $script:LoadedSecrets = @()

    foreach ($key in $Secrets.Keys) {
        if ($PSCmdlet.ShouldProcess("Environment variable $key", "Set value")) {
            [Environment]::SetEnvironmentVariable($key, $Secrets[$key])
            $script:LoadedSecrets += $key
            Write-Log "Set environment variable: $key" -Level Debug
        }
    }

    Write-Log "Loaded $($script:LoadedSecrets.Count) environment variables" -Level Info
    return $script:LoadedSecrets
}

function Clear-SecretEnvironment {
    [CmdletBinding()]
    param()

    foreach ($key in $script:LoadedSecrets) {
        [Environment]::SetEnvironmentVariable($key, $null)
        Write-Log "Cleared environment variable: $key" -Level Debug
    }

    Write-Log "Cleared $($script:LoadedSecrets.Count) environment variables" -Level Info
    $script:LoadedSecrets = @()
}

function Invoke-CommandWithSecrets {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$CommandArray
    )

    $executable = $CommandArray[0]
    $arguments = if ($CommandArray.Count -gt 1) { $CommandArray[1..($CommandArray.Count - 1)] } else { @() }

    Write-Log "Executing command: $executable $($arguments -join ' ')" -Level Info

    if ($PSCmdlet.ShouldProcess("$executable $($arguments -join ' ')", "Execute with secrets")) {
        try {
            & $executable @arguments
            $exitCode = $LASTEXITCODE

            return @{
                ExitCode = $exitCode
                Success = ($exitCode -eq 0)
            }
        }
        catch {
            Write-Log "Command execution failed: $_" -Level Error
            return @{
                ExitCode = 1
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    return @{
        ExitCode = 0
        Success = $true
        Skipped = $true
    }
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Running command with decrypted secrets" -Level Info
    Write-Log "Secrets file: $SecretsFile" -Level Info
    Write-Log "Command: $($Command -join ' ')" -Level Info

    # Verify secrets file
    $secretsPath = Test-SecretsFile

    # Decrypt secrets
    $decrypted = Get-DecryptedSecrets -FilePath $secretsPath

    # Convert to environment variables
    $envVars = ConvertTo-EnvironmentVariables -Content $decrypted.Content -Format $decrypted.Format

    if ($envVars.Count -eq 0) {
        Write-Log "No secrets found in file" -Level Warning
    }

    # Set environment variables
    $loadedKeys = Set-SecretEnvironment -Secrets $envVars

    # Execute command
    $commandResult = $null
    try {
        $commandResult = Invoke-CommandWithSecrets -CommandArray $Command
    }
    finally {
        # Always clear secrets
        Clear-SecretEnvironment
    }

    [PSCustomObject]@{
        Success           = $commandResult.Success
        Message           = if ($commandResult.Success) { "Command executed successfully" } else { "Command failed" }
        SecretsFile       = $secretsPath
        SecretsFormat     = $decrypted.Format
        SecretsCount      = $envVars.Count
        SecretKeys        = $loadedKeys
        Command           = $Command -join ' '
        ExitCode          = $commandResult.ExitCode
        Timestamp         = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    if ($Result.Success) {
        Write-Log "Script completed successfully" -Level Success
        Write-Log "Command exit code: $($Result.ExitCode)" -Level Info
    }
    else {
        Write-Log "Command failed with exit code: $($Result.ExitCode)" -Level Warning
    }

    Write-Log "End of $script:ScriptName" -Level Info
}

#endregion Main Functions

#region Main Execution

try {
    Initialize-Script

    $result = Invoke-MainLogic

    Complete-Script -Result $result

    # Exit with the same code as the executed command
    if ($result.ExitCode -and $result.ExitCode -ne 0) {
        exit $result.ExitCode
    }

    return $result
}
catch {
    Write-Log "Script failed: $_" -Level Error
    Write-Log $_.ScriptStackTrace -Level Debug

    # Ensure secrets are cleared on error
    Clear-SecretEnvironment

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
