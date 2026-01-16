#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Create and configure a Hyper-V External Virtual Switch for VM connectivity.

.DESCRIPTION
    This script creates an External Virtual Switch in Hyper-V that bridges VMs to the
    physical network. It performs the following actions:
    - Verifies Hyper-V is enabled and running
    - Lists available network adapters for selection
    - Creates an External switch bound to the selected adapter
    - Verifies the switch was created successfully

    Requires Administrator privileges to execute.

.PARAMETER SwitchName
    Name for the External Virtual Switch. Default: "External-DevSwitch"

.PARAMETER NetAdapterName
    Name of the physical network adapter to bind. If not specified, the script
    will auto-detect the first connected physical adapter.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> .\Configure-ExternalSwitch.ps1
    Creates an External switch named "External-DevSwitch" using auto-detected adapter.

.EXAMPLE
    PS> .\Configure-ExternalSwitch.ps1 -SwitchName "DevNetwork" -NetAdapterName "Ethernet"
    Creates an External switch named "DevNetwork" bound to the "Ethernet" adapter.

.EXAMPLE
    PS> .\Configure-ExternalSwitch.ps1 -WhatIf
    Shows what would happen without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Windows 10/11 Pro, Enterprise, or Server with Hyper-V enabled
    - Administrator privileges
    - At least one physical network adapter

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Name for the External Virtual Switch")]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName = "External-DevSwitch",

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Physical network adapter name (auto-detect if not specified)")]
    [string]$NetAdapterName
)

#region Configuration

# Strict mode for better error catching
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Script metadata
$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'

# Logging configuration
$script:LogFile = Join-Path $PSScriptRoot "../logs/$($ScriptName -replace '\.ps1$', '').log"

#endregion Configuration

#region Helper Functions

function Write-Log {
    <#
    .SYNOPSIS
        Write message to console and log file.
    #>
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

    # Console output with colour
    switch ($Level) {
        'Info'    { Write-Host $Message -ForegroundColor Cyan }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Host $Message -ForegroundColor Red }
        'Success' { Write-Host $Message -ForegroundColor Green }
        'Debug'   { Write-Debug $Message }
    }

    # File output
    if ($script:LogFile) {
        $logDir = Split-Path $script:LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Test-IsElevated {
    <#
    .SYNOPSIS
        Check if running with elevated privileges.
    #>
    [CmdletBinding()]
    param()

    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    return $false
}

function Test-HyperVEnabled {
    <#
    .SYNOPSIS
        Verify Hyper-V is enabled and the VMMS service is running.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Checking Hyper-V status..." -Level Debug

    # Check if Hyper-V module is available
    $hyperVModule = Get-Module -ListAvailable -Name Hyper-V -ErrorAction SilentlyContinue
    if (-not $hyperVModule) {
        throw "Hyper-V PowerShell module is not installed. Please enable Hyper-V feature."
    }

    # Check if VMMS service is running
    $vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if (-not $vmms) {
        throw "Hyper-V Virtual Machine Management service (vmms) is not installed."
    }

    if ($vmms.Status -ne 'Running') {
        throw "Hyper-V Virtual Machine Management service is not running. Current status: $($vmms.Status)"
    }

    Write-Log "Hyper-V is enabled and running" -Level Success
    return $true
}

function Get-AvailableNetAdapters {
    <#
    .SYNOPSIS
        Get list of physical network adapters suitable for External switch.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Discovering available network adapters..." -Level Info

    $adapters = Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and
        $_.Virtual -eq $false -and
        $_.InterfaceDescription -notmatch 'Hyper-V|Virtual|VPN|Loopback'
    }

    if ($adapters) {
        Write-Log "Available physical adapters:" -Level Info
        foreach ($adapter in $adapters) {
            Write-Log "  - $($adapter.Name): $($adapter.InterfaceDescription) [$($adapter.LinkSpeed)]" -Level Info
        }
    }
    else {
        Write-Log "No suitable physical adapters found" -Level Warning
    }

    return $adapters
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    <#
    .SYNOPSIS
        Perform script initialization and prerequisite checks.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug

    # Check for Administrator privileges
    if (-not (Test-IsElevated)) {
        throw "This script requires Administrator privileges. Please run as Administrator."
    }
    Write-Log "Running with Administrator privileges" -Level Success

    # Verify Hyper-V is enabled
    Test-HyperVEnabled | Out-Null
}

function New-ExternalVirtualSwitch {
    <#
    .SYNOPSIS
        Create the External Virtual Switch.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$SwitchName,

        [Parameter(Mandatory)]
        [string]$AdapterName
    )

    # Check if switch already exists
    $existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if ($existingSwitch) {
        Write-Log "Virtual switch '$SwitchName' already exists" -Level Warning
        return $existingSwitch
    }

    # Verify the adapter exists and is available
    $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if (-not $adapter) {
        throw "Network adapter '$AdapterName' not found."
    }

    if ($adapter.Status -ne 'Up') {
        throw "Network adapter '$AdapterName' is not connected (Status: $($adapter.Status))."
    }

    Write-Log "Creating External Virtual Switch '$SwitchName' bound to '$AdapterName'..." -Level Info

    if ($PSCmdlet.ShouldProcess("Hyper-V", "Create External Virtual Switch '$SwitchName' on adapter '$AdapterName'")) {
        $switch = New-VMSwitch -Name $SwitchName `
            -NetAdapterName $AdapterName `
            -AllowManagementOS $true `
            -Notes "External switch for development VMs - Created by $script:ScriptName"

        Write-Log "Virtual switch created successfully" -Level Success
        return $switch
    }

    return $null
}

function Test-VirtualSwitchCreation {
    <#
    .SYNOPSIS
        Verify the virtual switch was created correctly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SwitchName
    )

    Write-Log "Verifying virtual switch configuration..." -Level Info

    $switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $switch) {
        throw "Virtual switch '$SwitchName' verification failed - switch not found."
    }

    if ($switch.SwitchType -ne 'External') {
        throw "Virtual switch '$SwitchName' is not an External switch (Type: $($switch.SwitchType))."
    }

    # Get connected adapter info
    $netAdapter = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match "Hyper-V Virtual Ethernet Adapter" -and
        $_.Name -match $SwitchName
    }

    Write-Log "Switch '$SwitchName' verified successfully" -Level Success
    Write-Log "  Type: $($switch.SwitchType)" -Level Info
    Write-Log "  Allow Management OS: $($switch.AllowManagementOS)" -Level Info

    return $switch
}

function Invoke-MainLogic {
    <#
    .SYNOPSIS
        Main script logic for creating External Virtual Switch.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Get available adapters
    $availableAdapters = Get-AvailableNetAdapters

    # Determine which adapter to use
    $selectedAdapter = $null
    if ($script:NetAdapterName) {
        $selectedAdapter = $availableAdapters | Where-Object { $_.Name -eq $script:NetAdapterName }
        if (-not $selectedAdapter) {
            throw "Specified adapter '$script:NetAdapterName' is not available or not suitable for External switch."
        }
    }
    else {
        # Auto-detect: use the first available adapter
        $selectedAdapter = $availableAdapters | Select-Object -First 1
        if (-not $selectedAdapter) {
            throw "No suitable network adapter found for auto-detection. Please specify -NetAdapterName."
        }
        Write-Log "Auto-detected adapter: $($selectedAdapter.Name)" -Level Info
    }

    # Create the switch
    $switch = New-ExternalVirtualSwitch -SwitchName $SwitchName -AdapterName $selectedAdapter.Name

    # Verify creation (skip in WhatIf mode)
    if ($switch) {
        $verifiedSwitch = Test-VirtualSwitchCreation -SwitchName $SwitchName

        # Return result object
        return [PSCustomObject]@{
            Success            = $true
            SwitchName         = $verifiedSwitch.Name
            SwitchType         = $verifiedSwitch.SwitchType
            SwitchId           = $verifiedSwitch.Id
            NetAdapterName     = $selectedAdapter.Name
            AllowManagementOS  = $verifiedSwitch.AllowManagementOS
            Message            = "External Virtual Switch created successfully"
            Timestamp          = Get-Date
        }
    }

    # WhatIf mode result
    return [PSCustomObject]@{
        Success            = $true
        SwitchName         = $SwitchName
        SwitchType         = 'External'
        SwitchId           = $null
        NetAdapterName     = $selectedAdapter.Name
        AllowManagementOS  = $true
        Message            = "WhatIf: External Virtual Switch would be created"
        Timestamp          = Get-Date
    }
}

function Complete-Script {
    <#
    .SYNOPSIS
        Perform cleanup and final reporting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    if ($Result.Success) {
        Write-Log "Script completed successfully" -Level Success
        Write-Log "Switch Name: $($Result.SwitchName)" -Level Info
        Write-Log "Bound Adapter: $($Result.NetAdapterName)" -Level Info
    }
    else {
        Write-Log "Script completed with errors" -Level Warning
    }

    Write-Log "End of $script:ScriptName" -Level Info
}

#endregion Main Functions

#region Main Execution

# Store parameters for use in nested functions
$script:NetAdapterName = $NetAdapterName

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
        Success    = $false
        SwitchName = $SwitchName
        Error      = $_.Exception.Message
        Timestamp  = Get-Date
    }
}
finally {
    $ProgressPreference = 'Continue'
}

#endregion Main Execution
