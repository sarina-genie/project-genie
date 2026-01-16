#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Configure Git with user settings, aliases, and SOPS integration.

.DESCRIPTION
    Sets up Git configuration including:
    - User name and email
    - Default branch name
    - Useful aliases (st, co, br, ci, lg)
    - Core settings (editor, autocrlf)
    - Credential helper
    - SOPS diff driver for encrypted file diffs

    This script does not require root privileges.

.PARAMETER UserName
    The Git user name to configure.

.PARAMETER UserEmail
    The Git user email to configure.

.PARAMETER DefaultBranch
    The default branch name for new repositories. Defaults to "main".

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./Configure-Git.ps1 -UserName "John Doe" -UserEmail "john@example.com"
    Configures Git with the specified user name and email.

.EXAMPLE
    PS> ./Configure-Git.ps1 -UserName "Jane" -UserEmail "jane@example.com" -DefaultBranch "develop"
    Configures Git with a custom default branch.

.EXAMPLE
    PS> ./Configure-Git.ps1 -UserName "Test" -UserEmail "test@test.com" -WhatIf
    Shows what configuration changes would be made.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Git installed and available in PATH
    - SOPS installed (optional, for diff driver)

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Git user name")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Git user email")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[\w\.-]+@[\w\.-]+\.\w+$')]
    [string]$UserEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Default branch name")]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultBranch = "main"
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

function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-Log "Checking prerequisites..." -Level Debug

    $prerequisites = [ordered]@{
        'PowerShell 7+' = { $PSVersionTable.PSVersion.Major -ge 7 }
        'Git' = { Get-Command git -ErrorAction SilentlyContinue }
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

function Set-GitConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Key,
        [string]$Value,
        [switch]$Global
    )

    $scope = if ($Global) { '--global' } else { '' }
    $scopeDisplay = if ($Global) { 'global' } else { 'local' }

    if ($PSCmdlet.ShouldProcess("git config $scopeDisplay $Key", "Set to '$Value'")) {
        $args = @('config')
        if ($Global) { $args += '--global' }
        $args += @($Key, $Value)

        Invoke-NativeCommand -Command 'git' -Arguments $args
        Write-Log "Set $scopeDisplay git config: $Key = $Value" -Level Info
        return $true
    }
    return $false
}

function Set-UserConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $configured = @()

    if (Set-GitConfig -Key 'user.name' -Value $UserName -Global) {
        $configured += 'user.name'
    }

    if (Set-GitConfig -Key 'user.email' -Value $UserEmail -Global) {
        $configured += 'user.email'
    }

    if (Set-GitConfig -Key 'init.defaultBranch' -Value $DefaultBranch -Global) {
        $configured += 'init.defaultBranch'
    }

    return $configured
}

function Set-GitAliases {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $aliases = @{
        'st' = 'status'
        'co' = 'checkout'
        'br' = 'branch'
        'ci' = 'commit'
        'lg' = 'log --oneline --graph --decorate --all'
    }

    $configured = @()

    foreach ($alias in $aliases.GetEnumerator()) {
        if (Set-GitConfig -Key "alias.$($alias.Key)" -Value $alias.Value -Global) {
            $configured += $alias.Key
        }
    }

    return $configured
}

function Set-CoreSettings {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $settings = @{
        'core.editor' = 'vim'
        'core.autocrlf' = 'input'
        'core.pager' = 'less -FRX'
        'pull.rebase' = 'false'
        'push.default' = 'current'
        'color.ui' = 'auto'
    }

    $configured = @()

    foreach ($setting in $settings.GetEnumerator()) {
        if (Set-GitConfig -Key $setting.Key -Value $setting.Value -Global) {
            $configured += $setting.Key
        }
    }

    return $configured
}

function Set-CredentialHelper {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $helper = if ($IsLinux) {
        'cache --timeout=3600'
    }
    elseif ($IsMacOS) {
        'osxkeychain'
    }
    else {
        'manager-core'
    }

    if (Set-GitConfig -Key 'credential.helper' -Value $helper -Global) {
        return $helper
    }

    return $null
}

function Set-SopsDiffDriver {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Check if SOPS is installed
    $sopsAvailable = Get-Command sops -ErrorAction SilentlyContinue

    if (-not $sopsAvailable) {
        Write-Log "SOPS not found, skipping diff driver configuration" -Level Warning
        return $false
    }

    if ($PSCmdlet.ShouldProcess("git diff driver", "Configure SOPS diff driver")) {
        Set-GitConfig -Key 'diff.sops.textconv' -Value 'sops --decrypt' -Global | Out-Null
        Write-Log "Configured SOPS diff driver for encrypted files" -Level Info
        return $true
    }

    return $false
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Configuring Git for user: $UserName <$UserEmail>" -Level Info

    # Configure user settings
    Write-Log "Setting user configuration..." -Level Info
    $userSettings = Set-UserConfiguration

    # Configure aliases
    Write-Log "Setting up aliases..." -Level Info
    $aliases = Set-GitAliases

    # Configure core settings
    Write-Log "Setting core configuration..." -Level Info
    $coreSettings = Set-CoreSettings

    # Configure credential helper
    Write-Log "Setting credential helper..." -Level Info
    $credHelper = Set-CredentialHelper

    # Configure SOPS diff driver
    Write-Log "Setting up SOPS integration..." -Level Info
    $sopsConfigured = Set-SopsDiffDriver

    [PSCustomObject]@{
        Success          = $true
        Message          = "Git configuration completed successfully"
        UserName         = $UserName
        UserEmail        = $UserEmail
        DefaultBranch    = $DefaultBranch
        UserSettings     = $userSettings
        Aliases          = $aliases
        CoreSettings     = $coreSettings
        CredentialHelper = $credHelper
        SopsConfigured   = $sopsConfigured
        Timestamp        = Get-Date
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
        Write-Log "Configured $($Result.Aliases.Count) aliases, $($Result.CoreSettings.Count) core settings" -Level Info
    }
    else {
        Write-Log "Script completed with errors" -Level Warning
    }

    Write-Log "End of $script:ScriptName" -Level Info
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
