#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Create the standard directory structure for the development environment.

.DESCRIPTION
    Sets up the complete directory hierarchy for an isolated development environment:
    - ~/projects/ with category subdirectories (agents, web, devops, experiments, _templates, _archive, _shared)
    - ~/tools/ with utility subdirectories (scripts, dotfiles, bin, docker)
    - ~/docs/ for documentation

    This script does not require root privileges.

.PARAMETER HomeDirectory
    The home directory where the structure will be created. Defaults to $HOME.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./Setup-FileSystem.ps1
    Creates the directory structure in the current user's home directory.

.EXAMPLE
    PS> ./Setup-FileSystem.ps1 -HomeDirectory /home/devuser
    Creates the directory structure in a specific home directory.

.EXAMPLE
    PS> ./Setup-FileSystem.ps1 -WhatIf
    Shows what directories would be created without making changes.

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
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Home directory for structure creation")]
    [ValidateNotNullOrEmpty()]
    [string]$HomeDirectory = $HOME
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
        'Home Directory Exists' = { Test-Path $HomeDirectory }
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
        [switch]$PassThru
    )

    Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug

    $result = & $Command @Arguments 2>&1

    if ($LASTEXITCODE -ne 0) {
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
    Write-Log "Home Directory: $HomeDirectory" -Level Debug

    Test-Prerequisites
}

function New-DirectoryStructure {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $directories = @(
        # Projects directory structure
        "$HomeDirectory/projects/agents",
        "$HomeDirectory/projects/web",
        "$HomeDirectory/projects/devops",
        "$HomeDirectory/projects/experiments",
        "$HomeDirectory/projects/_templates",
        "$HomeDirectory/projects/_archive",
        "$HomeDirectory/projects/_shared",

        # Tools directory structure
        "$HomeDirectory/tools/scripts",
        "$HomeDirectory/tools/dotfiles",
        "$HomeDirectory/tools/bin",
        "$HomeDirectory/tools/docker",

        # Documentation directory
        "$HomeDirectory/docs"
    )

    $createdDirs = @()
    $existingDirs = @()

    foreach ($dir in $directories) {
        if (Test-Path $dir) {
            Write-Log "Directory already exists: $dir" -Level Debug
            $existingDirs += $dir
        }
        else {
            if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Log "Created directory: $dir" -Level Info
                $createdDirs += $dir
            }
        }
    }

    return @{
        Created = $createdDirs
        Existing = $existingDirs
    }
}

function Set-DirectoryPermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not ($IsLinux -or $IsMacOS)) {
        Write-Log "Skipping permissions setup on Windows" -Level Debug
        return $true
    }

    $dirsToSecure = @(
        "$HomeDirectory/projects",
        "$HomeDirectory/tools",
        "$HomeDirectory/docs"
    )

    foreach ($dir in $dirsToSecure) {
        if (Test-Path $dir) {
            if ($PSCmdlet.ShouldProcess($dir, "Set permissions to 755")) {
                Invoke-NativeCommand -Command 'chmod' -Arguments @('755', $dir)
                Write-Log "Set permissions 755 on: $dir" -Level Debug
            }
        }
    }

    # More restrictive permissions for tools/bin (executable scripts)
    $binDir = "$HomeDirectory/tools/bin"
    if (Test-Path $binDir) {
        if ($PSCmdlet.ShouldProcess($binDir, "Set permissions to 750")) {
            Invoke-NativeCommand -Command 'chmod' -Arguments @('750', $binDir)
            Write-Log "Set permissions 750 on: $binDir" -Level Debug
        }
    }

    return $true
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Setting up file system structure in $HomeDirectory" -Level Info

    # Create directory structure
    $dirResult = New-DirectoryStructure

    # Set permissions
    $permResult = Set-DirectoryPermissions

    # Generate summary
    $totalDirs = $dirResult.Created.Count + $dirResult.Existing.Count

    [PSCustomObject]@{
        Success          = $true
        Message          = "File system structure created successfully"
        HomeDirectory    = $HomeDirectory
        DirectoriesCreated = $dirResult.Created
        DirectoriesExisting = $dirResult.Existing
        TotalDirectories = $totalDirs
        PermissionsSet   = $permResult
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
        Write-Log "Created $($Result.DirectoriesCreated.Count) directories, $($Result.DirectoriesExisting.Count) already existed" -Level Info
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
