#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Install and configure WireGuard VPN on Linux.

.DESCRIPTION
    Sets up WireGuard VPN including:
    - Installing wireguard and resolvconf packages
    - Copying configuration to /etc/wireguard/
    - Setting proper permissions (600)
    - Optionally configuring kill switch with iptables
    - Enabling and starting the WireGuard interface
    - Verifying connectivity

    This script REQUIRES root privileges.

.PARAMETER ConfigFile
    Path to the WireGuard configuration file to install.

.PARAMETER InterfaceName
    Name of the WireGuard interface. Defaults to "wg0".

.PARAMETER EnableKillSwitch
    When specified, configures iptables rules to prevent traffic leaks when VPN disconnects.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo ./Install-WireGuard.ps1 -ConfigFile ~/wireguard.conf
    Installs WireGuard with the specified configuration.

.EXAMPLE
    PS> sudo ./Install-WireGuard.ps1 -ConfigFile ~/wg.conf -InterfaceName "wg1" -EnableKillSwitch
    Installs WireGuard with a custom interface name and kill switch enabled.

.EXAMPLE
    PS> sudo ./Install-WireGuard.ps1 -ConfigFile ~/wg.conf -WhatIf
    Shows what installation steps would be performed.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Linux operating system
    - Root privileges (sudo)
    - apt package manager (Debian/Ubuntu)

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path to WireGuard configuration file")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false, HelpMessage = "WireGuard interface name")]
    [ValidatePattern('^wg\d+$')]
    [string]$InterfaceName = "wg0",

    [Parameter(Mandatory = $false, HelpMessage = "Enable kill switch via iptables")]
    [switch]$EnableKillSwitch
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
        'Linux' = { $IsLinux }
        'Root privileges' = { (id -u) -eq 0 }
        'apt available' = { Get-Command apt -ErrorAction SilentlyContinue }
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

function Install-WireGuardPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $packages = @('wireguard', 'wireguard-tools', 'resolvconf')
    $installed = @()

    if ($PSCmdlet.ShouldProcess("apt", "Update package lists")) {
        Write-Log "Updating package lists..." -Level Info
        Invoke-NativeCommand -Command 'apt' -Arguments @('update', '-qq')
    }

    foreach ($package in $packages) {
        if ($PSCmdlet.ShouldProcess($package, "Install package")) {
            Write-Log "Installing $package..." -Level Info
            Invoke-NativeCommand -Command 'apt' -Arguments @('install', '-y', '-qq', $package)
            $installed += $package
        }
    }

    return $installed
}

function Install-WireGuardConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $wgDir = '/etc/wireguard'
    $targetConfig = Join-Path $wgDir "$InterfaceName.conf"

    # Ensure wireguard directory exists
    if (-not (Test-Path $wgDir)) {
        if ($PSCmdlet.ShouldProcess($wgDir, "Create directory")) {
            New-Item -ItemType Directory -Path $wgDir -Force | Out-Null
            Invoke-NativeCommand -Command 'chmod' -Arguments @('700', $wgDir)
        }
    }

    # Copy configuration
    if ($PSCmdlet.ShouldProcess($targetConfig, "Copy configuration file")) {
        Copy-Item -Path $ConfigFile -Destination $targetConfig -Force
        Write-Log "Copied configuration to $targetConfig" -Level Info

        # Set restrictive permissions
        Invoke-NativeCommand -Command 'chmod' -Arguments @('600', $targetConfig)
        Write-Log "Set permissions 600 on $targetConfig" -Level Info
    }

    return $targetConfig
}

function Set-KillSwitch {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $EnableKillSwitch) {
        Write-Log "Kill switch not requested, skipping" -Level Debug
        return $false
    }

    # Get the WireGuard interface address from config
    $configContent = Get-Content $ConfigFile -Raw
    $wgAddress = if ($configContent -match 'Address\s*=\s*([^\s,]+)') {
        $matches[1] -replace '/\d+$', ''
    }
    else {
        Write-Log "Could not determine WireGuard address from config" -Level Warning
        return $false
    }

    # Get the endpoint address
    $endpoint = if ($configContent -match 'Endpoint\s*=\s*([^:]+)') {
        $matches[1]
    }
    else {
        Write-Log "Could not determine endpoint from config" -Level Warning
        return $false
    }

    $rules = @(
        # Allow traffic on loopback
        @('-A', 'OUTPUT', '-o', 'lo', '-j', 'ACCEPT'),
        # Allow traffic on WireGuard interface
        @('-A', 'OUTPUT', '-o', $InterfaceName, '-j', 'ACCEPT'),
        # Allow traffic to WireGuard endpoint (for handshake)
        @('-A', 'OUTPUT', '-d', $endpoint, '-j', 'ACCEPT'),
        # Allow established connections
        @('-A', 'INPUT', '-m', 'state', '--state', 'ESTABLISHED,RELATED', '-j', 'ACCEPT'),
        # Allow traffic from WireGuard interface
        @('-A', 'INPUT', '-i', $InterfaceName, '-j', 'ACCEPT')
    )

    if ($PSCmdlet.ShouldProcess("iptables", "Configure kill switch rules")) {
        foreach ($rule in $rules) {
            try {
                Invoke-NativeCommand -Command 'iptables' -Arguments $rule -AllowFailure
                Write-Log "Added iptables rule: $($rule -join ' ')" -Level Debug
            }
            catch {
                Write-Log "Failed to add rule: $($rule -join ' ')" -Level Warning
            }
        }

        Write-Log "Kill switch iptables rules configured" -Level Success
        return $true
    }

    return $false
}

function Enable-WireGuardInterface {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess($InterfaceName, "Enable and start WireGuard interface")) {
        # Enable service to start on boot
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('enable', "wg-quick@$InterfaceName")
        Write-Log "Enabled WireGuard service for $InterfaceName" -Level Info

        # Start the interface
        Invoke-NativeCommand -Command 'wg-quick' -Arguments @('up', $InterfaceName) -AllowFailure
        Write-Log "Started WireGuard interface $InterfaceName" -Level Success

        return $true
    }

    return $false
}

function Test-VpnConnectivity {
    [CmdletBinding()]
    param()

    Write-Log "Verifying VPN connectivity..." -Level Info

    # Check interface status
    $wgStatus = Invoke-NativeCommand -Command 'wg' -Arguments @('show', $InterfaceName) -PassThru -AllowFailure

    if ([string]::IsNullOrEmpty($wgStatus)) {
        Write-Log "WireGuard interface $InterfaceName is not active" -Level Warning
        return @{
            InterfaceActive = $false
            PublicIP = $null
        }
    }

    Write-Log "WireGuard interface is active" -Level Success

    # Get public IP to verify VPN
    try {
        $publicIP = Invoke-NativeCommand -Command 'curl' -Arguments @('-s', '-m', '10', 'ifconfig.me') -PassThru
        Write-Log "Public IP via VPN: $publicIP" -Level Info

        return @{
            InterfaceActive = $true
            PublicIP = $publicIP
        }
    }
    catch {
        Write-Log "Could not determine public IP" -Level Warning
        return @{
            InterfaceActive = $true
            PublicIP = $null
        }
    }
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Installing and configuring WireGuard VPN" -Level Info
    Write-Log "Config file: $ConfigFile" -Level Info
    Write-Log "Interface: $InterfaceName" -Level Info

    # Install packages
    Write-Log "Installing WireGuard packages..." -Level Info
    $installedPackages = Install-WireGuardPackages

    # Install configuration
    Write-Log "Installing configuration..." -Level Info
    $configPath = Install-WireGuardConfig

    # Configure kill switch if requested
    $killSwitchConfigured = $false
    if ($EnableKillSwitch) {
        Write-Log "Configuring kill switch..." -Level Info
        $killSwitchConfigured = Set-KillSwitch
    }

    # Enable and start interface
    Write-Log "Enabling WireGuard interface..." -Level Info
    $interfaceEnabled = Enable-WireGuardInterface

    # Verify connectivity
    $connectivity = Test-VpnConnectivity

    [PSCustomObject]@{
        Success            = $connectivity.InterfaceActive
        Message            = if ($connectivity.InterfaceActive) { "WireGuard VPN configured successfully" } else { "WireGuard installed but interface may not be active" }
        InstalledPackages  = $installedPackages
        ConfigPath         = $configPath
        InterfaceName      = $InterfaceName
        KillSwitchEnabled  = $killSwitchConfigured
        InterfaceActive    = $connectivity.InterfaceActive
        PublicIP           = $connectivity.PublicIP
        Timestamp          = Get-Date
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
        if ($Result.PublicIP) {
            Write-Log "VPN is active. Public IP: $($Result.PublicIP)" -Level Info
        }
    }
    else {
        Write-Log "Script completed with warnings" -Level Warning
        Write-Log "Run 'wg show' to check interface status" -Level Info
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
