#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Harden VM security configuration on Ubuntu.

.DESCRIPTION
    This script configures security hardening on an Ubuntu VM:
    - Configures UFW firewall (default deny incoming, allow SSH, enable firewall)
    - Installs and configures fail2ban for intrusion prevention
    - Hardens SSH configuration (disable password auth, disable root login, set AllowUsers)
    - Sets secure file permissions on sensitive directories

    Prerequisites:
    - Ubuntu Linux operating system
    - Root/sudo privileges

.PARAMETER SSHPort
    The SSH port to allow through the firewall. Default is 22.

.PARAMETER AllowedUser
    The username to allow SSH access. If specified, SSH will be restricted to this user only.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> sudo pwsh ./Configure-Security.ps1
    Configures security with default settings (SSH on port 22).

.EXAMPLE
    PS> sudo pwsh ./Configure-Security.ps1 -SSHPort 2222 -AllowedUser "devuser"
    Configures security with SSH on port 2222 and restricts access to devuser.

.EXAMPLE
    PS> sudo pwsh ./Configure-Security.ps1 -WhatIf
    Shows what security changes would be made without applying them.

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
param(
    [Parameter(Mandatory = $false, HelpMessage = "SSH port to allow through firewall")]
    [ValidateRange(1, 65535)]
    [int]$SSHPort = 22,

    [Parameter(Mandatory = $false, HelpMessage = "Username to allow SSH access")]
    [ValidateNotNullOrEmpty()]
    [string]$AllowedUser
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

$script:SSHConfigPath = '/etc/ssh/sshd_config'
$script:Fail2BanJailPath = '/etc/fail2ban/jail.local'

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
    Write-Log "SSH Port: $SSHPort" -Level Debug
    if ($AllowedUser) {
        Write-Log "Allowed User: $AllowedUser" -Level Debug
    }

    Test-Prerequisites
}

function Install-UFW {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("ufw", "Install UFW firewall")) {
        Write-Log "Installing UFW..." -Level Info
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('update', '-qq')
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'ufw')
        Write-Log "UFW installed" -Level Success
    }
}

function Configure-UFW {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$Port
    )

    if ($PSCmdlet.ShouldProcess("UFW firewall", "Configure default deny and allow SSH")) {
        Write-Log "Configuring UFW firewall..." -Level Info

        # Reset UFW to defaults
        Invoke-NativeCommand -Command 'ufw' -Arguments @('--force', 'reset') -AllowFailure

        # Set default policies
        Invoke-NativeCommand -Command 'ufw' -Arguments @('default', 'deny', 'incoming')
        Invoke-NativeCommand -Command 'ufw' -Arguments @('default', 'allow', 'outgoing')

        # Allow SSH
        Invoke-NativeCommand -Command 'ufw' -Arguments @('allow', "$Port/tcp")
        Write-Log "Allowed SSH on port $Port" -Level Info

        # Enable UFW
        Invoke-NativeCommand -Command 'ufw' -Arguments @('--force', 'enable')
        Write-Log "UFW enabled" -Level Success

        # Show status
        $status = Invoke-NativeCommand -Command 'ufw' -Arguments @('status', 'verbose') -PassThru
        Write-Log "UFW Status: $status" -Level Debug
    }
}

function Install-Fail2Ban {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("fail2ban", "Install fail2ban")) {
        Write-Log "Installing fail2ban..." -Level Info
        Invoke-NativeCommand -Command 'apt-get' -Arguments @('install', '-y', '-qq', 'fail2ban')
        Write-Log "fail2ban installed" -Level Success
    }
}

function Configure-Fail2Ban {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$Port
    )

    if ($PSCmdlet.ShouldProcess($script:Fail2BanJailPath, "Configure fail2ban jail")) {
        Write-Log "Configuring fail2ban..." -Level Info

        $jailConfig = @"
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = $Port
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
"@

        Set-Content -Path $script:Fail2BanJailPath -Value $jailConfig -Force
        Write-Log "fail2ban jail.local configured" -Level Success

        # Restart fail2ban
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('restart', 'fail2ban')
        Invoke-NativeCommand -Command 'systemctl' -Arguments @('enable', 'fail2ban')
        Write-Log "fail2ban service enabled and restarted" -Level Success
    }
}

function Backup-SSHConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $backupPath = "$($script:SSHConfigPath).backup.$(Get-Date -Format 'yyyyMMddHHmmss')"

    if ($PSCmdlet.ShouldProcess($script:SSHConfigPath, "Create backup")) {
        if (Test-Path $script:SSHConfigPath) {
            Copy-Item -Path $script:SSHConfigPath -Destination $backupPath -Force
            Write-Log "SSH config backed up to $backupPath" -Level Info
        }
    }

    return $backupPath
}

function Configure-SSHHardening {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$Port,
        [string]$User
    )

    if ($PSCmdlet.ShouldProcess($script:SSHConfigPath, "Harden SSH configuration")) {
        Write-Log "Hardening SSH configuration..." -Level Info

        # Backup existing config
        Backup-SSHConfig

        # Read current config
        $sshConfig = Get-Content -Path $script:SSHConfigPath -Raw

        # Settings to apply
        $settings = @{
            'Port' = $Port
            'PermitRootLogin' = 'no'
            'PasswordAuthentication' = 'no'
            'PubkeyAuthentication' = 'yes'
            'ChallengeResponseAuthentication' = 'no'
            'UsePAM' = 'yes'
            'X11Forwarding' = 'no'
            'PrintMotd' = 'no'
            'AcceptEnv' = 'LANG LC_*'
            'Subsystem' = 'sftp /usr/lib/openssh/sftp-server'
        }

        if ($User) {
            $settings['AllowUsers'] = $User
        }

        foreach ($setting in $settings.GetEnumerator()) {
            $pattern = "^#?\s*$($setting.Key)\s+.*$"
            $replacement = "$($setting.Key) $($setting.Value)"

            if ($sshConfig -match $pattern) {
                $sshConfig = $sshConfig -replace $pattern, $replacement
            }
            else {
                $sshConfig += "`n$replacement"
            }
        }

        Set-Content -Path $script:SSHConfigPath -Value $sshConfig -Force
        Write-Log "SSH configuration updated" -Level Success

        # Test configuration
        $testResult = Invoke-NativeCommand -Command 'sshd' -Arguments @('-t') -PassThru -AllowFailure
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SSH configuration test passed" -Level Success

            # Restart SSH service
            Invoke-NativeCommand -Command 'systemctl' -Arguments @('restart', 'sshd') -AllowFailure
            if ($LASTEXITCODE -ne 0) {
                Invoke-NativeCommand -Command 'systemctl' -Arguments @('restart', 'ssh')
            }
            Write-Log "SSH service restarted" -Level Success
        }
        else {
            Write-Log "SSH configuration test failed: $testResult" -Level Error
            throw "SSH configuration validation failed"
        }
    }
}

function Set-SecurePermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("System directories", "Set secure permissions")) {
        Write-Log "Setting secure permissions..." -Level Info

        # Secure SSH directory
        if (Test-Path '/etc/ssh') {
            Invoke-NativeCommand -Command 'chmod' -Arguments @('700', '/etc/ssh')
            Invoke-NativeCommand -Command 'chmod' -Arguments @('600', '/etc/ssh/sshd_config')
            Write-Log "SSH directory permissions secured" -Level Success
        }

        # Secure home directories
        $homeBase = '/home'
        if (Test-Path $homeBase) {
            $homes = Get-ChildItem -Path $homeBase -Directory
            foreach ($home in $homes) {
                $sshDir = Join-Path $home.FullName '.ssh'
                if (Test-Path $sshDir) {
                    Invoke-NativeCommand -Command 'chmod' -Arguments @('700', $sshDir)
                    $authKeys = Join-Path $sshDir 'authorized_keys'
                    if (Test-Path $authKeys) {
                        Invoke-NativeCommand -Command 'chmod' -Arguments @('600', $authKeys)
                    }
                }
            }
            Write-Log "Home directory permissions secured" -Level Success
        }
    }
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $startTime = Get-Date
    $changes = @()

    # Install and configure UFW
    Install-UFW
    Configure-UFW -Port $SSHPort
    $changes += "UFW configured (port $SSHPort allowed)"

    # Install and configure fail2ban
    Install-Fail2Ban
    Configure-Fail2Ban -Port $SSHPort
    $changes += "fail2ban configured"

    # Harden SSH
    Configure-SSHHardening -Port $SSHPort -User $AllowedUser
    $changes += "SSH hardened"
    if ($AllowedUser) {
        $changes += "SSH access restricted to user: $AllowedUser"
    }

    # Set secure permissions
    Set-SecurePermissions
    $changes += "Secure permissions applied"

    $endTime = Get-Date
    $duration = $endTime - $startTime

    [PSCustomObject]@{
        Success       = $true
        SSHPort       = $SSHPort
        AllowedUser   = $AllowedUser
        Changes       = $changes
        Duration      = $duration
        Timestamp     = Get-Date
    }
}

function Complete-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    Write-Log "" -Level Info
    Write-Log "=== Security Configuration Summary ===" -Level Info
    Write-Log "SSH Port: $($Result.SSHPort)" -Level Info
    if ($Result.AllowedUser) {
        Write-Log "Allowed User: $($Result.AllowedUser)" -Level Info
    }
    Write-Log "Changes applied:" -Level Info
    foreach ($change in $Result.Changes) {
        Write-Log "  - $change" -Level Info
    }
    Write-Log "Duration: $($Result.Duration.TotalSeconds.ToString('F1')) seconds" -Level Info

    if ($Result.Success) {
        Write-Log "Security configuration completed successfully" -Level Success
    }
    else {
        Write-Log "Security configuration completed with errors" -Level Warning
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
