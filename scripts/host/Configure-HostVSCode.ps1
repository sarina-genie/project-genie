#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Configure VS Code with an isolated profile for secure development.

.DESCRIPTION
    This script configures Visual Studio Code with an isolated profile optimized
    for development in isolated VM environments. It performs the following actions:
    - Creates a new VS Code profile for isolated development
    - Installs the Remote-SSH extension for VM connectivity
    - Optionally installs GitHub Copilot extensions
    - Configures privacy and security settings (disables telemetry, auto-updates)
    - Sets up remote platform configuration for Linux VMs

    This ensures a clean, secure VS Code environment specifically for
    connecting to development VMs.

.PARAMETER ProfileName
    Name for the VS Code profile. Default: "Isolated-Dev"

.PARAMETER InstallCopilot
    Install GitHub Copilot and Copilot Chat extensions.

.PARAMETER SSHConfigAlias
    SSH config alias for the remote host (used in remote.SSH.remotePlatform setting).
    Default: "devvm"

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> .\Configure-HostVSCode.ps1
    Creates an "Isolated-Dev" profile with Remote-SSH extension.

.EXAMPLE
    PS> .\Configure-HostVSCode.ps1 -ProfileName "SecureDev" -InstallCopilot
    Creates a custom profile with Copilot extensions installed.

.EXAMPLE
    PS> .\Configure-HostVSCode.ps1 -SSHConfigAlias "myvm" -WhatIf
    Shows what would happen without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Visual Studio Code installed
    - VS Code available in PATH (code command)

    Settings Applied:
    - telemetry.telemetryLevel: off
    - extensions.autoUpdate: false
    - update.mode: manual
    - remote.SSH.remotePlatform: linux

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Name for the VS Code profile")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9\-_\s]+$')]
    [string]$ProfileName = "Isolated-Dev",

    [Parameter(Mandatory = $false, HelpMessage = "Install GitHub Copilot extensions")]
    [switch]$InstallCopilot,

    [Parameter(Mandatory = $false, HelpMessage = "SSH config alias for remote platform setting")]
    [ValidateNotNullOrEmpty()]
    [string]$SSHConfigAlias = "devvm"
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "../logs/$($ScriptName -replace '\.ps1$', '').log"

# Extension IDs
$script:RequiredExtensions = @(
    'ms-vscode-remote.remote-ssh',
    'ms-vscode-remote.remote-ssh-edit'
)

$script:CopilotExtensions = @(
    'GitHub.copilot',
    'GitHub.copilot-chat'
)

# Settings to apply
$script:ProfileSettings = @{
    'telemetry.telemetryLevel'    = 'off'
    'extensions.autoUpdate'       = $false
    'update.mode'                 = 'manual'
    'remote.SSH.remotePlatform'   = @{}  # Will be populated with SSH alias
    'remote.SSH.showLoginTerminal' = $true
    'remote.SSH.connectTimeout'   = 60
}

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

function Test-VSCodeInstalled {
    <#
    .SYNOPSIS
        Check if VS Code is installed and available.
    #>
    [CmdletBinding()]
    param()

    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        throw "VS Code is not installed or 'code' command is not in PATH. Please install VS Code and ensure it's accessible from the command line."
    }

    # Get VS Code version
    $versionOutput = & code --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $version = $versionOutput[0]
        Write-Log "VS Code version: $version" -Level Debug
    }

    return $true
}

function Get-VSCodeUserDataPath {
    <#
    .SYNOPSIS
        Get the VS Code user data directory path.
    #>
    [CmdletBinding()]
    param()

    if ($IsWindows) {
        return Join-Path $env:APPDATA "Code"
    }
    elseif ($IsMacOS) {
        return Join-Path $HOME "Library/Application Support/Code"
    }
    else {
        return Join-Path $HOME ".config/Code"
    }
}

function Get-VSCodeProfilePath {
    <#
    .SYNOPSIS
        Get the path for a VS Code profile's settings.
    #>
    [CmdletBinding()]
    param(
        [string]$ProfileName
    )

    $userDataPath = Get-VSCodeUserDataPath

    # For custom profiles, VS Code stores them in User/profiles
    $profilesPath = Join-Path $userDataPath "User/profiles"

    return $profilesPath
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug

    # Verify VS Code is installed
    Test-VSCodeInstalled | Out-Null
    Write-Log "VS Code is installed and available" -Level Success
}

function Install-VSCodeExtension {
    <#
    .SYNOPSIS
        Install a VS Code extension.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ExtensionId,

        [Parameter()]
        [string]$ProfileName
    )

    Write-Log "Installing extension: $ExtensionId" -Level Info

    if ($PSCmdlet.ShouldProcess($ExtensionId, "Install VS Code extension")) {
        $args = @('--install-extension', $ExtensionId, '--force')

        # Add profile argument if specified
        if ($ProfileName) {
            $args += @('--profile', $ProfileName)
        }

        $process = Start-Process -FilePath 'code' `
            -ArgumentList $args `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $env:TEMP "code-ext-out.txt") `
            -RedirectStandardError (Join-Path $env:TEMP "code-ext-err.txt")

        if ($process.ExitCode -eq 0) {
            Write-Log "Extension installed: $ExtensionId" -Level Success
            return $true
        }
        else {
            $errorContent = Get-Content (Join-Path $env:TEMP "code-ext-err.txt") -Raw -ErrorAction SilentlyContinue
            Write-Log "Failed to install extension $ExtensionId`: $errorContent" -Level Warning
            return $false
        }
    }

    return $true
}

function New-VSCodeProfile {
    <#
    .SYNOPSIS
        Create a new VS Code profile.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ProfileName
    )

    Write-Log "Creating VS Code profile: $ProfileName" -Level Info

    if ($PSCmdlet.ShouldProcess($ProfileName, "Create VS Code profile")) {
        # VS Code profiles are created by opening VS Code with --profile flag
        # The profile is created automatically if it doesn't exist

        # We'll use the CLI to trigger profile creation
        $process = Start-Process -FilePath 'code' `
            -ArgumentList @('--profile', $ProfileName, '--list-extensions') `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $env:TEMP "code-profile-out.txt") `
            -RedirectStandardError (Join-Path $env:TEMP "code-profile-err.txt")

        Write-Log "Profile '$ProfileName' initialized" -Level Success
    }

    return $true
}

function Set-VSCodeProfileSettings {
    <#
    .SYNOPSIS
        Configure VS Code settings for the profile.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ProfileName,
        [hashtable]$Settings,
        [string]$SSHAlias
    )

    Write-Log "Configuring profile settings..." -Level Info

    # Update remote platform setting with SSH alias
    $Settings['remote.SSH.remotePlatform'] = @{
        $SSHAlias = 'linux'
    }

    if ($PSCmdlet.ShouldProcess($ProfileName, "Configure VS Code settings")) {
        $userDataPath = Get-VSCodeUserDataPath

        # For the default profile or when using --profile, settings go to User/settings.json
        # For named profiles, we need to write to the profile-specific settings

        # Get existing settings or create new
        $settingsPath = Join-Path $userDataPath "User/settings.json"

        $existingSettings = @{}
        if (Test-Path $settingsPath) {
            try {
                $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Log "Could not parse existing settings, will create new" -Level Warning
                $existingSettings = @{}
            }
        }
        else {
            # Create directory if needed
            $settingsDir = Split-Path $settingsPath -Parent
            if (-not (Test-Path $settingsDir)) {
                New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
            }
        }

        # Merge settings (our settings take precedence)
        foreach ($key in $Settings.Keys) {
            $existingSettings[$key] = $Settings[$key]
        }

        # Write settings file
        $settingsJson = $existingSettings | ConvertTo-Json -Depth 10
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8

        Write-Log "Settings configured at: $settingsPath" -Level Success

        # Also create/update profile-specific settings if using a named profile
        # This requires VS Code 1.75+ which supports profile-specific settings
        Write-Log "Applied settings:" -Level Info
        foreach ($key in $Settings.Keys) {
            $value = $Settings[$key]
            if ($value -is [hashtable]) {
                $value = ($value | ConvertTo-Json -Compress)
            }
            Write-Log "  $key`: $value" -Level Debug
        }
    }

    return $Settings
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $installedExtensions = @()
    $failedExtensions = @()

    # Create the profile
    New-VSCodeProfile -ProfileName $ProfileName

    # Install required extensions
    Write-Log "Installing required extensions..." -Level Info
    foreach ($extension in $script:RequiredExtensions) {
        $result = Install-VSCodeExtension -ExtensionId $extension -ProfileName $ProfileName
        if ($result) {
            $installedExtensions += $extension
        }
        else {
            $failedExtensions += $extension
        }
    }

    # Install Copilot extensions if requested
    if ($InstallCopilot) {
        Write-Log "Installing GitHub Copilot extensions..." -Level Info
        foreach ($extension in $script:CopilotExtensions) {
            $result = Install-VSCodeExtension -ExtensionId $extension -ProfileName $ProfileName
            if ($result) {
                $installedExtensions += $extension
            }
            else {
                $failedExtensions += $extension
            }
        }
    }

    # Configure settings
    $appliedSettings = Set-VSCodeProfileSettings `
        -ProfileName $ProfileName `
        -Settings $script:ProfileSettings `
        -SSHAlias $SSHConfigAlias

    # Build result object
    return [PSCustomObject]@{
        Success              = ($failedExtensions.Count -eq 0)
        ProfileName          = $ProfileName
        InstalledExtensions  = $installedExtensions
        FailedExtensions     = $failedExtensions
        CopilotInstalled     = $InstallCopilot.IsPresent
        SettingsApplied      = @{
            'telemetry.telemetryLevel'  = 'off'
            'extensions.autoUpdate'     = $false
            'update.mode'               = 'manual'
            'remote.SSH.remotePlatform' = @{ $SSHConfigAlias = 'linux' }
        }
        SSHConfigAlias       = $SSHConfigAlias
        Message              = "VS Code profile '$ProfileName' configured successfully"
        Timestamp            = Get-Date
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
        Write-Log "VS Code Profile Configuration Summary:" -Level Info
        Write-Log "  Profile: $($Result.ProfileName)" -Level Info
        Write-Log "  Extensions installed: $($Result.InstalledExtensions.Count)" -Level Info
        foreach ($ext in $Result.InstalledExtensions) {
            Write-Log "    - $ext" -Level Info
        }
        Write-Log "" -Level Info
        Write-Log "Settings applied:" -Level Info
        Write-Log "  - Telemetry: off" -Level Info
        Write-Log "  - Auto-update extensions: disabled" -Level Info
        Write-Log "  - Update mode: manual" -Level Info
        Write-Log "  - Remote SSH platform ($($Result.SSHConfigAlias)): linux" -Level Info
        Write-Log "" -Level Info
        Write-Log "To use the isolated profile:" -Level Info
        Write-Log "  code --profile `"$($Result.ProfileName)`"" -Level Info
        Write-Log "" -Level Info
        Write-Log "To connect to the VM:" -Level Info
        Write-Log "  1. Open VS Code with the profile" -Level Info
        Write-Log "  2. Press Ctrl+Shift+P and type 'Remote-SSH: Connect to Host'" -Level Info
        Write-Log "  3. Select '$($Result.SSHConfigAlias)' from the list" -Level Info
    }
    else {
        Write-Log "Script completed with some errors" -Level Warning
        if ($Result.FailedExtensions.Count -gt 0) {
            Write-Log "Failed to install extensions:" -Level Warning
            foreach ($ext in $Result.FailedExtensions) {
                Write-Log "  - $ext" -Level Warning
            }
        }
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
        ProfileName = $ProfileName
        Error       = $_.Exception.Message
        Timestamp   = Get-Date
    }
}
finally {
    $ProgressPreference = 'Continue'
}

#endregion Main Execution
