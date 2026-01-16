#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Create and configure a Hyper-V virtual machine for isolated development.

.DESCRIPTION
    This script creates a Generation 2 Hyper-V virtual machine configured for
    Ubuntu development environments. It performs the following actions:
    - Validates the ISO installation media exists
    - Creates a Generation 2 VM with specified resources
    - Configures dynamic memory with specified min/max bounds
    - Creates and attaches a VHDX virtual disk
    - Connects the VM to the specified virtual switch
    - Disables Secure Boot for Ubuntu compatibility
    - Attaches the ISO as the primary boot device
    - Optionally enables MAC address spoofing for nested virtualization

    Requires Administrator privileges to execute.

.PARAMETER VMName
    Name for the virtual machine. Default: "DEV-VM-01"

.PARAMETER ISOPath
    Full path to the Ubuntu installation ISO file. Required.

.PARAMETER VHDPath
    Path where the virtual hard disk will be created. If not specified,
    defaults to the Hyper-V default virtual hard disk path.

.PARAMETER MemoryGB
    Amount of startup memory in GB. Default: 12

.PARAMETER ProcessorCount
    Number of virtual processors. Default: 8

.PARAMETER DiskSizeGB
    Size of the virtual hard disk in GB. Default: 250

.PARAMETER SwitchName
    Name of the virtual switch to connect. Default: "External-DevSwitch"

.PARAMETER EnableMACSpoof
    Enable MAC address spoofing for nested virtualization scenarios.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> .\Create-IsolatedDevVM.ps1 -ISOPath "C:\ISOs\ubuntu-24.04-desktop-amd64.iso"
    Creates a VM with default settings using the specified ISO.

.EXAMPLE
    PS> .\Create-IsolatedDevVM.ps1 -VMName "DEV-VM-02" -ISOPath "C:\ISOs\ubuntu.iso" -MemoryGB 16 -ProcessorCount 12
    Creates a VM with custom name, 16GB RAM, and 12 processors.

.EXAMPLE
    PS> .\Create-IsolatedDevVM.ps1 -ISOPath "C:\ISOs\ubuntu.iso" -EnableMACSpoof -WhatIf
    Shows what would happen when creating a VM with MAC spoofing enabled.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Windows 10/11 Pro, Enterprise, or Server with Hyper-V enabled
    - Administrator privileges
    - Sufficient disk space for VHD
    - Valid Ubuntu ISO file

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Name for the virtual machine")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9\-_]+$')]
    [string]$VMName = "DEV-VM-01",

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Path to Ubuntu installation ISO")]
    [ValidateNotNullOrEmpty()]
    [string]$ISOPath,

    [Parameter(Mandatory = $false, HelpMessage = "Path for the virtual hard disk")]
    [string]$VHDPath,

    [Parameter(Mandatory = $false, HelpMessage = "Startup memory in GB")]
    [ValidateRange(4, 64)]
    [int]$MemoryGB = 12,

    [Parameter(Mandatory = $false, HelpMessage = "Number of virtual processors")]
    [ValidateRange(2, 32)]
    [int]$ProcessorCount = 8,

    [Parameter(Mandatory = $false, HelpMessage = "Virtual disk size in GB")]
    [ValidateRange(50, 2000)]
    [int]$DiskSizeGB = 250,

    [Parameter(Mandatory = $false, HelpMessage = "Virtual switch name")]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName = "External-DevSwitch",

    [Parameter(Mandatory = $false, HelpMessage = "Enable MAC address spoofing")]
    [switch]$EnableMACSpoof
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "../logs/$($ScriptName -replace '\.ps1$', '').log"

# Dynamic memory configuration (GB)
$script:MinMemoryGB = 8
$script:MaxMemoryGB = 16

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

    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return $false
}

function Test-HyperVEnabled {
    [CmdletBinding()]
    param()

    $hyperVModule = Get-Module -ListAvailable -Name Hyper-V -ErrorAction SilentlyContinue
    if (-not $hyperVModule) {
        throw "Hyper-V PowerShell module is not installed."
    }

    $vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if (-not $vmms -or $vmms.Status -ne 'Running') {
        throw "Hyper-V Virtual Machine Management service is not running."
    }

    return $true
}

function Get-DefaultVHDPath {
    [CmdletBinding()]
    param()

    $vmHost = Get-VMHost
    return $vmHost.VirtualHardDiskPath
}

#endregion Helper Functions

#region Main Functions

function Initialize-Script {
    [CmdletBinding()]
    param()

    Write-Log "Starting $script:ScriptName v$script:ScriptVersion" -Level Info
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug

    if (-not (Test-IsElevated)) {
        throw "This script requires Administrator privileges."
    }
    Write-Log "Running with Administrator privileges" -Level Success

    Test-HyperVEnabled | Out-Null
    Write-Log "Hyper-V is enabled and running" -Level Success
}

function Test-VMPrerequisites {
    <#
    .SYNOPSIS
        Validate all prerequisites before VM creation.
    #>
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ISOPath,
        [string]$VHDPath,
        [string]$SwitchName
    )

    Write-Log "Validating prerequisites..." -Level Info

    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        throw "A VM named '$VMName' already exists. Please choose a different name or remove the existing VM."
    }

    # Validate ISO path
    if (-not (Test-Path $ISOPath -PathType Leaf)) {
        throw "ISO file not found: $ISOPath"
    }

    $isoExtension = [System.IO.Path]::GetExtension($ISOPath).ToLower()
    if ($isoExtension -ne '.iso') {
        throw "Invalid ISO file: Expected .iso extension, got '$isoExtension'"
    }

    Write-Log "ISO validated: $ISOPath" -Level Success

    # Check if VHD path directory exists
    if ($VHDPath) {
        $vhdDir = Split-Path $VHDPath -Parent
        if (-not (Test-Path $vhdDir)) {
            Write-Log "VHD directory will be created: $vhdDir" -Level Info
        }

        if (Test-Path $VHDPath) {
            throw "VHD file already exists: $VHDPath"
        }
    }

    # Validate virtual switch exists
    $switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $switch) {
        throw "Virtual switch '$SwitchName' not found. Please create it first using Configure-ExternalSwitch.ps1"
    }
    Write-Log "Virtual switch validated: $SwitchName" -Level Success

    # Check available disk space (need at least DiskSizeGB + 10GB buffer)
    $vhdLocation = if ($VHDPath) { Split-Path $VHDPath -Parent } else { Get-DefaultVHDPath }
    $drive = (Get-Item $vhdLocation -ErrorAction SilentlyContinue).PSDrive
    if ($drive) {
        $freeSpaceGB = [math]::Round(($drive.Free / 1GB), 2)
        $requiredSpaceGB = $DiskSizeGB + 10
        if ($freeSpaceGB -lt $requiredSpaceGB) {
            throw "Insufficient disk space. Required: ${requiredSpaceGB}GB, Available: ${freeSpaceGB}GB"
        }
        Write-Log "Disk space validated: ${freeSpaceGB}GB available" -Level Success
    }

    Write-Log "All prerequisites validated" -Level Success
}

function New-DevelopmentVM {
    <#
    .SYNOPSIS
        Create and configure the Hyper-V virtual machine.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$VMName,
        [string]$ISOPath,
        [string]$VHDPath,
        [int]$MemoryGB,
        [int]$ProcessorCount,
        [int]$DiskSizeGB,
        [string]$SwitchName,
        [bool]$EnableMACSpoof
    )

    $memoryBytes = $MemoryGB * 1GB
    $minMemoryBytes = $script:MinMemoryGB * 1GB
    $maxMemoryBytes = $script:MaxMemoryGB * 1GB
    $diskSizeBytes = $DiskSizeGB * 1GB

    # Determine VHD path
    if (-not $VHDPath) {
        $defaultPath = Get-DefaultVHDPath
        $VHDPath = Join-Path $defaultPath "$VMName.vhdx"
    }

    Write-Log "Creating Generation 2 VM: $VMName" -Level Info
    Write-Log "  Memory: ${MemoryGB}GB (Dynamic: $script:MinMemoryGB-$script:MaxMemoryGB GB)" -Level Info
    Write-Log "  Processors: $ProcessorCount" -Level Info
    Write-Log "  Disk: ${DiskSizeGB}GB at $VHDPath" -Level Info
    Write-Log "  Switch: $SwitchName" -Level Info
    Write-Log "  ISO: $ISOPath" -Level Info

    if ($PSCmdlet.ShouldProcess($VMName, "Create Hyper-V Virtual Machine")) {
        # Create the VM
        $vm = New-VM -Name $VMName `
            -Generation 2 `
            -MemoryStartupBytes $memoryBytes `
            -SwitchName $SwitchName `
            -NoVHD

        Write-Log "VM created successfully" -Level Success

        # Configure dynamic memory
        Write-Log "Configuring dynamic memory..." -Level Info
        Set-VMMemory -VMName $VMName `
            -DynamicMemoryEnabled $true `
            -MinimumBytes $minMemoryBytes `
            -MaximumBytes $maxMemoryBytes `
            -StartupBytes $memoryBytes

        # Configure processors
        Write-Log "Configuring processors..." -Level Info
        Set-VMProcessor -VMName $VMName -Count $ProcessorCount

        # Create and attach VHD
        Write-Log "Creating virtual hard disk..." -Level Info
        $vhdDir = Split-Path $VHDPath -Parent
        if (-not (Test-Path $vhdDir)) {
            New-Item -ItemType Directory -Path $vhdDir -Force | Out-Null
        }

        $vhd = New-VHD -Path $VHDPath -SizeBytes $diskSizeBytes -Dynamic
        Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

        # Disable Secure Boot for Ubuntu
        Write-Log "Disabling Secure Boot for Ubuntu compatibility..." -Level Info
        Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

        # Attach ISO to DVD drive
        Write-Log "Attaching installation ISO..." -Level Info
        Add-VMDvdDrive -VMName $VMName -Path $ISOPath

        # Set boot order: DVD first, then HDD
        Write-Log "Configuring boot order..." -Level Info
        $dvdDrive = Get-VMDvdDrive -VMName $VMName
        $hardDrive = Get-VMHardDiskDrive -VMName $VMName
        Set-VMFirmware -VMName $VMName -BootOrder $dvdDrive, $hardDrive

        # Enable MAC address spoofing if requested
        if ($EnableMACSpoof) {
            Write-Log "Enabling MAC address spoofing..." -Level Info
            $networkAdapter = Get-VMNetworkAdapter -VMName $VMName
            Set-VMNetworkAdapter -VMName $VMName -MacAddressSpoofing On
        }

        # Enable guest services for integration
        Write-Log "Enabling integration services..." -Level Info
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"

        # Get final VM state
        $finalVM = Get-VM -Name $VMName
        $networkAdapter = Get-VMNetworkAdapter -VMName $VMName

        return [PSCustomObject]@{
            VM            = $finalVM
            VHDPath       = $VHDPath
            NetworkAdapter = $networkAdapter
        }
    }

    return $null
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Validate prerequisites
    Test-VMPrerequisites -VMName $VMName -ISOPath $ISOPath -VHDPath $VHDPath -SwitchName $SwitchName

    # Create the VM
    $vmResult = New-DevelopmentVM `
        -VMName $VMName `
        -ISOPath $ISOPath `
        -VHDPath $VHDPath `
        -MemoryGB $MemoryGB `
        -ProcessorCount $ProcessorCount `
        -DiskSizeGB $DiskSizeGB `
        -SwitchName $SwitchName `
        -EnableMACSpoof $EnableMACSpoof.IsPresent

    if ($vmResult) {
        return [PSCustomObject]@{
            Success        = $true
            VMName         = $vmResult.VM.Name
            State          = $vmResult.VM.State.ToString()
            IPAddress      = $null  # Will be available after OS installation
            VHDPath        = $vmResult.VHDPath
            MemoryGB       = $MemoryGB
            ProcessorCount = $ProcessorCount
            DiskSizeGB     = $DiskSizeGB
            SwitchName     = $SwitchName
            MACAddress     = $vmResult.NetworkAdapter.MacAddress
            Message        = "VM created successfully. Start the VM and install Ubuntu from the attached ISO."
            Timestamp      = Get-Date
        }
    }

    # WhatIf result
    return [PSCustomObject]@{
        Success        = $true
        VMName         = $VMName
        State          = 'Off'
        IPAddress      = $null
        VHDPath        = $VHDPath
        MemoryGB       = $MemoryGB
        ProcessorCount = $ProcessorCount
        DiskSizeGB     = $DiskSizeGB
        SwitchName     = $SwitchName
        MACAddress     = $null
        Message        = "WhatIf: VM would be created with specified configuration"
        Timestamp      = Get-Date
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
        Write-Log "VM Name: $($Result.VMName)" -Level Info
        Write-Log "State: $($Result.State)" -Level Info
        Write-Log "VHD Path: $($Result.VHDPath)" -Level Info

        if ($Result.State -eq 'Off') {
            Write-Log "" -Level Info
            Write-Log "Next steps:" -Level Info
            Write-Log "  1. Start the VM: Start-VM -Name '$($Result.VMName)'" -Level Info
            Write-Log "  2. Connect to console: vmconnect localhost '$($Result.VMName)'" -Level Info
            Write-Log "  3. Install Ubuntu from the attached ISO" -Level Info
            Write-Log "  4. Configure SSH and networking in the VM" -Level Info
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
        Success   = $false
        VMName    = $VMName
        Error     = $_.Exception.Message
        Timestamp = Get-Date
    }
}
finally {
    $ProgressPreference = 'Continue'
}

#endregion Main Execution
