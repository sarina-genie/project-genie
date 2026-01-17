#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Configure SSH client for secure access to development VMs.

.DESCRIPTION
    This script configures the SSH client on the Windows host for connecting to
    development VMs. It performs the following actions:
    - Creates the ~/.ssh directory if it doesn't exist
    - Generates an Ed25519 SSH key pair if not already present
    - Adds a configuration entry to ~/.ssh/config for easy VM access
    - Optionally tests the SSH connection to verify configuration

    The generated SSH configuration enables streamlined access to VMs using
    a simple alias (e.g., 'ssh devvm').

.PARAMETER VMHostname
    IP address or hostname of the VM to connect to. Required.

.PARAMETER VMUser
    Username for SSH connection to the VM. Default: "dev"

.PARAMETER IdentityFile
    Path to the SSH private key. If not specified, generates a new Ed25519 key
    at ~/.ssh/id_ed25519_devvm.

.PARAMETER ConfigAlias
    Alias name for the SSH config entry. Default: "devvm"

.PARAMETER SkipConnectionTest
    Skip the SSH connection test after configuration.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> .\Configure-SSHConfig.ps1 -VMHostname "192.168.1.100"
    Configures SSH access to the VM at the specified IP address.

.EXAMPLE
    PS> .\Configure-SSHConfig.ps1 -VMHostname "192.168.1.100" -VMUser "developer" -ConfigAlias "myvm"
    Configures SSH with custom username and alias.

.EXAMPLE
    PS> .\Configure-SSHConfig.ps1 -VMHostname "devvm.local" -IdentityFile "~/.ssh/custom_key"
    Uses an existing SSH key for the configuration.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - OpenSSH client installed (included in Windows 10/11)
    - Network connectivity to the VM

    Security Notes:
    - ForwardAgent is disabled by default for security
    - Ed25519 keys are used for modern security standards
    - Key permissions are set to user-only access

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "IP address or hostname of the VM")]
    [ValidateNotNullOrEmpty()]
    [string]$VMHostname,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "SSH username for the VM")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$VMUser = "dev",

    [Parameter(Mandatory = $false, HelpMessage = "Path to SSH private key")]
    [string]$IdentityFile,

    [Parameter(Mandatory = $false, HelpMessage = "Alias name for SSH config entry")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9\-_]+$')]
    [string]$ConfigAlias = "devvm",

    [Parameter(Mandatory = $false, HelpMessage = "Skip SSH connection test")]
    [switch]$SkipConnectionTest
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "../logs/$($ScriptName -replace '\.ps1$', '').log"

# SSH configuration
$script:SSHDir = Join-Path $HOME ".ssh"
$script:SSHConfigPath = Join-Path $script:SSHDir "config"
$script:DefaultKeyName = "id_ed25519_devvm"

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

function Test-SSHAvailable {
    <#
    .SYNOPSIS
        Check if OpenSSH client is available.
    #>
    [CmdletBinding()]
    param()

    $sshCommand = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCommand) {
        throw "OpenSSH client is not installed. Please install OpenSSH Client from Windows Optional Features."
    }

    $sshKeygenCommand = Get-Command ssh-keygen -ErrorAction SilentlyContinue
    if (-not $sshKeygenCommand) {
        throw "ssh-keygen is not available. Please ensure OpenSSH is properly installed."
    }

    return $true
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug

    # Verify SSH is available
    Test-SSHAvailable | Out-Null
    Write-Log "OpenSSH client is available" -Level Success
}

function Initialize-SSHDirectory {
    <#
    .SYNOPSIS
        Create and configure the ~/.ssh directory.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Checking SSH directory..." -Level Info

    if (-not (Test-Path $script:SSHDir)) {
        if ($PSCmdlet.ShouldProcess($script:SSHDir, "Create SSH directory")) {
            Write-Log "Creating SSH directory: $($script:SSHDir)" -Level Info
            New-Item -ItemType Directory -Path $script:SSHDir -Force | Out-Null

            # Set secure permissions on Windows
            if ($IsWindows) {
                $acl = Get-Acl $script:SSHDir
                $acl.SetAccessRuleProtection($true, $false)
                $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $identity.Name,
                    "FullControl",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($rule)
                Set-Acl -Path $script:SSHDir -AclObject $acl
            }

            Write-Log "SSH directory created with secure permissions" -Level Success
        }
    }
    else {
        Write-Log "SSH directory exists: $($script:SSHDir)" -Level Success
    }
}

function New-SSHKeyPair {
    <#
    .SYNOPSIS
        Generate a new Ed25519 SSH key pair.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$KeyPath
    )

    $privateKeyPath = $KeyPath
    $publicKeyPath = "$KeyPath.pub"

    # Check if key already exists
    if (Test-Path $privateKeyPath) {
        Write-Log "SSH key already exists: $privateKeyPath" -Level Warning
        return $privateKeyPath
    }

    Write-Log "Generating Ed25519 SSH key pair..." -Level Info

    if ($PSCmdlet.ShouldProcess($privateKeyPath, "Generate SSH key pair")) {
        # Generate key without passphrase for automation (user can add passphrase later)
        $keyComment = "devvm-$(Get-Date -Format 'yyyyMMdd')-$env:USERNAME@$env:COMPUTERNAME"

        # Use ssh-keygen with appropriate parameters
        $sshKeygenArgs = @(
            '-t', 'ed25519',
            '-f', $privateKeyPath,
            '-N', '""',
            '-C', $keyComment
        )

        $process = Start-Process -FilePath 'ssh-keygen' `
            -ArgumentList $sshKeygenArgs `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $env:TEMP "ssh-keygen-out.txt") `
            -RedirectStandardError (Join-Path $env:TEMP "ssh-keygen-err.txt")

        if ($process.ExitCode -ne 0) {
            $errorContent = Get-Content (Join-Path $env:TEMP "ssh-keygen-err.txt") -Raw -ErrorAction SilentlyContinue
            throw "Failed to generate SSH key: $errorContent"
        }

        # Verify key was created
        if (-not (Test-Path $privateKeyPath) -or -not (Test-Path $publicKeyPath)) {
            throw "SSH key generation did not produce expected files."
        }

        # Set secure permissions on the private key
        if ($IsWindows) {
            $acl = Get-Acl $privateKeyPath
            $acl.SetAccessRuleProtection($true, $false)
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identity.Name,
                "Read",
                "None",
                "None",
                "Allow"
            )
            $acl.AddAccessRule($rule)
            Set-Acl -Path $privateKeyPath -AclObject $acl
        }

        Write-Log "SSH key pair generated successfully" -Level Success
        Write-Log "Private key: $privateKeyPath" -Level Info
        Write-Log "Public key: $publicKeyPath" -Level Info

        # Display public key for user to copy to VM
        $publicKey = Get-Content $publicKeyPath -Raw
        Write-Log "" -Level Info
        Write-Log "Public key to add to VM's ~/.ssh/authorized_keys:" -Level Info
        Write-Log $publicKey.Trim() -Level Info
        Write-Log "" -Level Info
    }

    return $privateKeyPath
}

function Add-SSHConfigEntry {
    <#
    .SYNOPSIS
        Add or update SSH config entry for the VM.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Alias,
        [string]$Hostname,
        [string]$User,
        [string]$IdentityFile
    )

    Write-Log "Configuring SSH config entry for '$Alias'..." -Level Info

    # Build the config entry
    $configEntry = @"

# Development VM - Added by Configure-SSHConfig.ps1 on $(Get-Date -Format 'yyyy-MM-dd')
Host $Alias
    HostName $Hostname
    User $User
    IdentityFile $IdentityFile
    ForwardAgent no
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
"@

    if ($PSCmdlet.ShouldProcess($script:SSHConfigPath, "Add SSH config entry for '$Alias'")) {
        # Check if config file exists
        if (Test-Path $script:SSHConfigPath) {
            $existingConfig = Get-Content $script:SSHConfigPath -Raw

            # Check if entry already exists
            if ($existingConfig -match "(?m)^Host\s+$Alias\s*$") {
                Write-Log "SSH config entry for '$Alias' already exists. Updating..." -Level Warning

                # Remove existing entry (from Host line to next Host line or end)
                $pattern = "(?ms)(\r?\n)?# Development VM - Added by Configure-SSHConfig\.ps1[^\r\n]*\r?\nHost $Alias\r?\n.*?(?=(\r?\n# |\r?\nHost |\z))"
                $existingConfig = $existingConfig -replace $pattern, ""

                # Write updated config
                Set-Content -Path $script:SSHConfigPath -Value $existingConfig.TrimEnd() -NoNewline
            }
        }

        # Append new entry
        Add-Content -Path $script:SSHConfigPath -Value $configEntry

        Write-Log "SSH config entry added for '$Alias'" -Level Success
    }

    return $configEntry
}

function Test-SSHConnection {
    <#
    .SYNOPSIS
        Test SSH connection to the VM.
    #>
    [CmdletBinding()]
    param(
        [string]$Alias
    )

    Write-Log "Testing SSH connection to '$Alias'..." -Level Info

    try {
        # Try to connect with a short timeout
        $process = Start-Process -FilePath 'ssh' `
            -ArgumentList @('-o', 'ConnectTimeout=10', '-o', 'BatchMode=yes', $Alias, 'echo "SSH connection successful"') `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $env:TEMP "ssh-test-out.txt") `
            -RedirectStandardError (Join-Path $env:TEMP "ssh-test-err.txt")

        if ($process.ExitCode -eq 0) {
            Write-Log "SSH connection test successful" -Level Success
            return $true
        }
        else {
            $errorContent = Get-Content (Join-Path $env:TEMP "ssh-test-err.txt") -Raw -ErrorAction SilentlyContinue
            Write-Log "SSH connection test failed: $errorContent" -Level Warning
            Write-Log "This is expected if the VM is not yet configured with the SSH public key." -Level Info
            return $false
        }
    }
    catch {
        Write-Log "SSH connection test error: $_" -Level Warning
        return $false
    }
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Initialize SSH directory
    Initialize-SSHDirectory

    # Determine identity file path
    $keyPath = $IdentityFile
    if (-not $keyPath) {
        $keyPath = Join-Path $script:SSHDir $script:DefaultKeyName
    }
    else {
        # Expand ~ to home directory
        $keyPath = $keyPath -replace '^~', $HOME
    }

    # Generate key pair if needed
    $actualKeyPath = New-SSHKeyPair -KeyPath $keyPath

    # Add SSH config entry
    $configEntry = Add-SSHConfigEntry `
        -Alias $ConfigAlias `
        -Hostname $VMHostname `
        -User $VMUser `
        -IdentityFile $keyPath

    # Test connection if not skipped
    $connectionSuccess = $null
    if (-not $SkipConnectionTest -and -not $WhatIfPreference) {
        $connectionSuccess = Test-SSHConnection -Alias $ConfigAlias
    }

    # Get public key content for result
    $publicKeyPath = "$keyPath.pub"
    $publicKey = if (Test-Path $publicKeyPath) {
        Get-Content $publicKeyPath -Raw -ErrorAction SilentlyContinue
    } else { $null }

    return [PSCustomObject]@{
        Success           = $true
        ConfigAlias       = $ConfigAlias
        VMHostname        = $VMHostname
        VMUser            = $VMUser
        IdentityFile      = $keyPath
        PublicKeyFile     = $publicKeyPath
        PublicKey         = $publicKey?.Trim()
        SSHConfigPath     = $script:SSHConfigPath
        ConnectionTested  = -not $SkipConnectionTest
        ConnectionSuccess = $connectionSuccess
        Message           = "SSH configuration completed. Use 'ssh $ConfigAlias' to connect."
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
        Write-Log "" -Level Info
        Write-Log "SSH Configuration Summary:" -Level Info
        Write-Log "  Alias: $($Result.ConfigAlias)" -Level Info
        Write-Log "  Host: $($Result.VMHostname)" -Level Info
        Write-Log "  User: $($Result.VMUser)" -Level Info
        Write-Log "  Key: $($Result.IdentityFile)" -Level Info
        Write-Log "" -Level Info
        Write-Log "To connect to the VM:" -Level Info
        Write-Log "  ssh $($Result.ConfigAlias)" -Level Info
        Write-Log "" -Level Info

        if (-not $Result.ConnectionSuccess) {
            Write-Log "Next steps to enable SSH access:" -Level Warning
            Write-Log "  1. Copy the public key to the VM's ~/.ssh/authorized_keys" -Level Info
            Write-Log "  2. Ensure SSH server is running on the VM (sudo systemctl start ssh)" -Level Info
            Write-Log "  3. Verify firewall allows SSH (port 22)" -Level Info
        }
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
        Success     = $false
        ConfigAlias = $ConfigAlias
        VMHostname  = $VMHostname
        Error       = $_.Exception.Message
        Timestamp   = Get-Date
    }
}
finally {
    $ProgressPreference = 'Continue'
}

#endregion Main Execution
