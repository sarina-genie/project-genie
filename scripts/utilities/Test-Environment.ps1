#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Validate the complete development environment setup.

.DESCRIPTION
    Performs comprehensive environment validation:
    - Checks PowerShell version
    - Tests connectivity (SSH, internet, VPN if applicable)
    - Verifies tool installations (Docker, Git, Node, Python, Claude Code, Age, SOPS)
    - Validates directory structure
    - Generates a formatted report with checkmarks

    Works on both Host and VM environments. Does not require root privileges.

.PARAMETER SkipConnectivity
    Skip network connectivity tests.

.PARAMETER SkipVpn
    Skip VPN connectivity check.

.PARAMETER Detailed
    Show detailed information for each check.

.PARAMETER WhatIf
    Shows what checks would be performed. No actual checks are made.

.PARAMETER Confirm
    Prompts for confirmation before running checks.

.EXAMPLE
    PS> ./Test-Environment.ps1
    Runs all environment validation checks and displays a report.

.EXAMPLE
    PS> ./Test-Environment.ps1 -SkipConnectivity
    Runs validation but skips network connectivity tests.

.EXAMPLE
    PS> ./Test-Environment.ps1 -Detailed
    Shows detailed output for each validation check.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Skip network connectivity tests")]
    [switch]$SkipConnectivity,

    [Parameter(Mandatory = $false, HelpMessage = "Skip VPN connectivity check")]
    [switch]$SkipVpn,

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed information")]
    [switch]$Detailed
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

# Check symbols
$script:CheckPass = "[PASS]"
$script:CheckFail = "[FAIL]"
$script:CheckWarn = "[WARN]"
$script:CheckSkip = "[SKIP]"

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

function Write-CheckResult {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail = ''
    )

    $symbol = switch ($Status) {
        'Pass' { $script:CheckPass; 'Green' }
        'Fail' { $script:CheckFail; 'Red' }
        'Warn' { $script:CheckWarn; 'Yellow' }
        'Skip' { $script:CheckSkip; 'Gray' }
    }

    $color = switch ($Status) {
        'Pass' { 'Green' }
        'Fail' { 'Red' }
        'Warn' { 'Yellow' }
        'Skip' { 'Gray' }
    }

    $line = "{0,-8} {1}" -f $symbol, $Name
    Write-Host $line -ForegroundColor $color

    if ($Detail -and $Detailed) {
        Write-Host "         $Detail" -ForegroundColor DarkGray
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
        [switch]$PassThru
    )

    Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug

    $result = & $Command @Arguments 2>&1

    if ($PassThru) {
        return @{
            Output = $result
            ExitCode = $LASTEXITCODE
            Success = ($LASTEXITCODE -eq 0)
        }
    }
}

#endregion Helper Functions

#region Check Functions

function Test-PowerShellVersion {
    [CmdletBinding()]
    param()

    $version = $PSVersionTable.PSVersion
    $versionStr = "$($version.Major).$($version.Minor).$($version.Build)"

    $result = @{
        Name = "PowerShell Version"
        Passed = $version.Major -ge 7
        Version = $versionStr
        Detail = "Version: $versionStr (Required: 7.0+)"
    }

    return $result
}

function Test-InternetConnectivity {
    [CmdletBinding()]
    param()

    if ($SkipConnectivity) {
        return @{
            Name = "Internet Connectivity"
            Passed = $null
            Skipped = $true
            Detail = "Skipped by user request"
        }
    }

    try {
        $response = Invoke-WebRequest -Uri 'https://www.google.com' -Method Head -TimeoutSec 10 -UseBasicParsing
        return @{
            Name = "Internet Connectivity"
            Passed = $true
            Detail = "HTTP $($response.StatusCode)"
        }
    }
    catch {
        return @{
            Name = "Internet Connectivity"
            Passed = $false
            Detail = "Failed to reach google.com"
        }
    }
}

function Test-SshConnectivity {
    [CmdletBinding()]
    param()

    if ($SkipConnectivity) {
        return @{
            Name = "SSH Client"
            Passed = $null
            Skipped = $true
            Detail = "Skipped by user request"
        }
    }

    $ssh = Get-Command ssh -ErrorAction SilentlyContinue

    if ($ssh) {
        $version = & ssh -V 2>&1
        return @{
            Name = "SSH Client"
            Passed = $true
            Detail = "$version"
        }
    }

    return @{
        Name = "SSH Client"
        Passed = $false
        Detail = "SSH not found in PATH"
    }
}

function Test-VpnConnectivity {
    [CmdletBinding()]
    param()

    if ($SkipConnectivity -or $SkipVpn) {
        return @{
            Name = "VPN (WireGuard)"
            Passed = $null
            Skipped = $true
            Detail = "Skipped by user request"
        }
    }

    # Check if WireGuard is installed
    $wg = Get-Command wg -ErrorAction SilentlyContinue

    if (-not $wg) {
        return @{
            Name = "VPN (WireGuard)"
            Passed = $null
            Skipped = $true
            Detail = "WireGuard not installed"
        }
    }

    # Check if any interface is active
    try {
        $interfaces = & wg show interfaces 2>$null
        if ($interfaces) {
            return @{
                Name = "VPN (WireGuard)"
                Passed = $true
                Detail = "Active interfaces: $interfaces"
            }
        }
        else {
            return @{
                Name = "VPN (WireGuard)"
                Passed = $null
                Warning = $true
                Detail = "WireGuard installed but no active interfaces"
            }
        }
    }
    catch {
        return @{
            Name = "VPN (WireGuard)"
            Passed = $null
            Warning = $true
            Detail = "Could not query WireGuard status"
        }
    }
}

function Test-ToolInstallation {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$VersionArgs = @('--version')
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue

    if ($cmd) {
        try {
            $version = & $Command @VersionArgs 2>&1 | Select-Object -First 1
            return @{
                Name = $Name
                Passed = $true
                Path = $cmd.Source
                Detail = "$version"
            }
        }
        catch {
            return @{
                Name = $Name
                Passed = $true
                Path = $cmd.Source
                Detail = "Installed (version check failed)"
            }
        }
    }

    return @{
        Name = $Name
        Passed = $false
        Detail = "Not found in PATH"
    }
}

function Test-DirectoryStructure {
    [CmdletBinding()]
    param()

    $requiredDirs = @(
        "$HOME/projects",
        "$HOME/projects/agents",
        "$HOME/projects/web",
        "$HOME/projects/devops",
        "$HOME/projects/experiments",
        "$HOME/projects/_templates",
        "$HOME/projects/_archive",
        "$HOME/projects/_shared",
        "$HOME/tools",
        "$HOME/tools/scripts",
        "$HOME/tools/dotfiles",
        "$HOME/tools/bin",
        "$HOME/tools/docker",
        "$HOME/docs"
    )

    $missing = @()
    $found = @()

    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir) {
            $found += $dir
        }
        else {
            $missing += $dir
        }
    }

    $passed = $missing.Count -eq 0

    return @{
        Name = "Directory Structure"
        Passed = $passed
        Found = $found
        Missing = $missing
        Detail = if ($passed) { "All $($found.Count) directories present" } else { "Missing: $($missing.Count) directories" }
    }
}

function Test-EnvironmentVariables {
    [CmdletBinding()]
    param()

    $checks = @{
        'SOPS_AGE_KEY_FILE' = $env:SOPS_AGE_KEY_FILE
        'EDITOR' = $env:EDITOR
    }

    $set = @()
    $notSet = @()

    foreach ($check in $checks.GetEnumerator()) {
        if ($check.Value) {
            $set += $check.Key
        }
        else {
            $notSet += $check.Key
        }
    }

    $passed = $notSet.Count -eq 0

    return @{
        Name = "Environment Variables"
        Passed = $passed
        Set = $set
        NotSet = $notSet
        Detail = if ($passed) { "All environment variables set" } else { "Missing: $($notSet -join ', ')" }
    }
}

function Test-GitConfiguration {
    [CmdletBinding()]
    param()

    $git = Get-Command git -ErrorAction SilentlyContinue

    if (-not $git) {
        return @{
            Name = "Git Configuration"
            Passed = $false
            Detail = "Git not installed"
        }
    }

    $userName = & git config --global user.name 2>$null
    $userEmail = & git config --global user.email 2>$null

    $configured = (-not [string]::IsNullOrEmpty($userName)) -and (-not [string]::IsNullOrEmpty($userEmail))

    return @{
        Name = "Git Configuration"
        Passed = $configured
        UserName = $userName
        UserEmail = $userEmail
        Detail = if ($configured) { "User: $userName <$userEmail>" } else { "Missing user.name or user.email" }
    }
}

#endregion Check Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug
    Write-Log "OS: $($PSVersionTable.OS)" -Level Debug
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess("Development environment", "Validate")) {
        return [PSCustomObject]@{
            Success = $true
            Message = "WhatIf mode - no checks performed"
            Timestamp = Get-Date
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Development Environment Validation   " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    # PowerShell Version
    Write-Host "System Checks:" -ForegroundColor White
    Write-Host "--------------" -ForegroundColor White

    $psCheck = Test-PowerShellVersion
    $results += $psCheck
    Write-CheckResult -Name $psCheck.Name -Status $(if ($psCheck.Passed) { 'Pass' } else { 'Fail' }) -Detail $psCheck.Detail

    # Connectivity
    Write-Host ""
    Write-Host "Connectivity:" -ForegroundColor White
    Write-Host "-------------" -ForegroundColor White

    $internetCheck = Test-InternetConnectivity
    $results += $internetCheck
    $status = if ($internetCheck.Skipped) { 'Skip' } elseif ($internetCheck.Passed) { 'Pass' } else { 'Fail' }
    Write-CheckResult -Name $internetCheck.Name -Status $status -Detail $internetCheck.Detail

    $sshCheck = Test-SshConnectivity
    $results += $sshCheck
    $status = if ($sshCheck.Skipped) { 'Skip' } elseif ($sshCheck.Passed) { 'Pass' } else { 'Fail' }
    Write-CheckResult -Name $sshCheck.Name -Status $status -Detail $sshCheck.Detail

    $vpnCheck = Test-VpnConnectivity
    $results += $vpnCheck
    $status = if ($vpnCheck.Skipped) { 'Skip' } elseif ($vpnCheck.Warning) { 'Warn' } elseif ($vpnCheck.Passed) { 'Pass' } else { 'Fail' }
    Write-CheckResult -Name $vpnCheck.Name -Status $status -Detail $vpnCheck.Detail

    # Tools
    Write-Host ""
    Write-Host "Tools:" -ForegroundColor White
    Write-Host "------" -ForegroundColor White

    $tools = @(
        @{ Name = "Docker"; Command = "docker"; VersionArgs = @('--version') },
        @{ Name = "Git"; Command = "git"; VersionArgs = @('--version') },
        @{ Name = "Node.js"; Command = "node"; VersionArgs = @('--version') },
        @{ Name = "Python"; Command = "python3"; VersionArgs = @('--version') },
        @{ Name = "Claude Code"; Command = "claude"; VersionArgs = @('--version') },
        @{ Name = "Age"; Command = "age"; VersionArgs = @('--version') },
        @{ Name = "SOPS"; Command = "sops"; VersionArgs = @('--version') }
    )

    foreach ($tool in $tools) {
        $check = Test-ToolInstallation -Name $tool.Name -Command $tool.Command -VersionArgs $tool.VersionArgs
        $results += $check
        Write-CheckResult -Name $check.Name -Status $(if ($check.Passed) { 'Pass' } else { 'Fail' }) -Detail $check.Detail
    }

    # Configuration
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "--------------" -ForegroundColor White

    $dirCheck = Test-DirectoryStructure
    $results += $dirCheck
    Write-CheckResult -Name $dirCheck.Name -Status $(if ($dirCheck.Passed) { 'Pass' } else { 'Fail' }) -Detail $dirCheck.Detail

    $envCheck = Test-EnvironmentVariables
    $results += $envCheck
    $status = if ($envCheck.Passed) { 'Pass' } elseif ($envCheck.NotSet.Count -lt 2) { 'Warn' } else { 'Fail' }
    Write-CheckResult -Name $envCheck.Name -Status $status -Detail $envCheck.Detail

    $gitCheck = Test-GitConfiguration
    $results += $gitCheck
    Write-CheckResult -Name $gitCheck.Name -Status $(if ($gitCheck.Passed) { 'Pass' } else { 'Fail' }) -Detail $gitCheck.Detail

    # Summary
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $passed = ($results | Where-Object { $_.Passed -eq $true }).Count
    $failed = ($results | Where-Object { $_.Passed -eq $false }).Count
    $skipped = ($results | Where-Object { $_.Skipped -eq $true }).Count
    $warnings = ($results | Where-Object { $_.Warning -eq $true }).Count
    $total = $results.Count

    Write-Host ""
    Write-Host "  Passed:   $passed" -ForegroundColor Green
    Write-Host "  Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "  Skipped:  $skipped" -ForegroundColor Gray
    Write-Host "  Total:    $total" -ForegroundColor Cyan
    Write-Host ""

    $overallSuccess = $failed -eq 0

    if ($overallSuccess) {
        Write-Host "  Environment is ready!" -ForegroundColor Green
    }
    else {
        Write-Host "  Environment has issues. Please fix failed checks." -ForegroundColor Red
    }

    Write-Host ""

    [PSCustomObject]@{
        Success       = $overallSuccess
        Message       = if ($overallSuccess) { "All checks passed" } else { "$failed check(s) failed" }
        Passed        = $passed
        Failed        = $failed
        Warnings      = $warnings
        Skipped       = $skipped
        Total         = $total
        Results       = $results
        Timestamp     = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    if ($Result.Success) {
        Write-Log "Environment validation completed successfully" -Level Success
    }
    else {
        Write-Log "Environment validation found $($Result.Failed) issue(s)" -Level Warning
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
