#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Configure bash shell environment with PATH, variables, functions, and aliases.

.DESCRIPTION
    Sets up the bash shell environment by modifying ~/.bashrc:
    - Adds PATH entries (~/tools/bin, ~/.local/bin)
    - Sets environment variables (SOPS_AGE_KEY_FILE, EDITOR)
    - Adds shell functions (cdp for project navigation, newproj for project creation)
    - Adds useful aliases for common commands

    This script does not require root privileges.

.PARAMETER BashrcPath
    Path to the bashrc file to modify. Defaults to ~/.bashrc.

.PARAMETER AgeKeyPath
    Path to the age key file for SOPS. Defaults to ~/.config/sops/age/keys.txt.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./Configure-Shell.ps1
    Configures the default ~/.bashrc with standard settings.

.EXAMPLE
    PS> ./Configure-Shell.ps1 -AgeKeyPath "/custom/path/keys.txt"
    Configures bashrc with a custom age key path.

.EXAMPLE
    PS> ./Configure-Shell.ps1 -WhatIf
    Shows what changes would be made to bashrc.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Linux or macOS (bash shell)

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to bashrc file")]
    [ValidateNotNullOrEmpty()]
    [string]$BashrcPath = "$HOME/.bashrc",

    [Parameter(Mandatory = $false, HelpMessage = "Path to age key file for SOPS")]
    [ValidateNotNullOrEmpty()]
    [string]$AgeKeyPath = "$HOME/.config/sops/age/keys.txt"
)

#region Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptName = $MyInvocation.MyCommand.Name
$script:ScriptVersion = '1.0.0'
$script:LogFile = Join-Path $PSScriptRoot "logs/$($ScriptName -replace '\.ps1$', '').log"

# Marker for our configuration block
$script:ConfigMarkerStart = "# >>> Project Genie Shell Configuration >>>"
$script:ConfigMarkerEnd = "# <<< Project Genie Shell Configuration <<<"

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
        'Linux or macOS' = { $IsLinux -or $IsMacOS }
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
    Write-Log "Bashrc Path: $BashrcPath" -Level Debug

    Test-Prerequisites
}

function Get-ShellConfiguration {
    [CmdletBinding()]
    param()

    $config = @"

$script:ConfigMarkerStart
# Generated by Project Genie on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# PATH additions
export PATH="`$HOME/tools/bin:`$HOME/.local/bin:`$PATH"

# Environment variables
export SOPS_AGE_KEY_FILE="$AgeKeyPath"
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less -FRX"

# Project navigation function
# Usage: cdp [project-name]
cdp() {
    local projects_dir="`$HOME/projects"
    if [ -z "`$1" ]; then
        cd "`$projects_dir" || return
    else
        local found
        found=`$(find "`$projects_dir" -maxdepth 2 -type d -name "`$1" 2>/dev/null | head -1)
        if [ -n "`$found" ]; then
            cd "`$found" || return
        else
            echo "Project '`$1' not found in `$projects_dir"
            return 1
        fi
    fi
}

# New project function
# Usage: newproj <project-name> [category]
newproj() {
    local name="`$1"
    local category="`${2:-experiments}"
    local projects_dir="`$HOME/projects"

    if [ -z "`$name" ]; then
        echo "Usage: newproj <project-name> [category]"
        echo "Categories: agents, web, devops, experiments"
        return 1
    fi

    local target_dir="`$projects_dir/`$category/`$name"

    if [ -d "`$target_dir" ]; then
        echo "Project already exists: `$target_dir"
        return 1
    fi

    mkdir -p "`$target_dir"
    cd "`$target_dir" || return
    git init
    echo "# `$name" > README.md
    git add README.md
    git commit -m "Initial commit"
    echo "Created new project: `$target_dir"
}

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias h='history'
alias path='echo -e `${PATH//:/\\n}'
alias now='date +"%Y-%m-%d %H:%M:%S"'

# Git aliases (complement git config aliases)
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git pull'
alias gps='git push'
alias glog='git log --oneline --graph --decorate -20'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# Quick directory bookmarks
alias proj='cd ~/projects'
alias tools='cd ~/tools'
alias docs='cd ~/docs'

$script:ConfigMarkerEnd
"@

    return $config
}

function Remove-ExistingConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Content
    )

    if ($Content -match [regex]::Escape($script:ConfigMarkerStart)) {
        Write-Log "Removing existing Project Genie configuration..." -Level Info

        $pattern = "(?s)$([regex]::Escape($script:ConfigMarkerStart)).*?$([regex]::Escape($script:ConfigMarkerEnd))\r?\n?"
        $newContent = $Content -replace $pattern, ''

        return $newContent
    }

    return $Content
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Configuring shell environment in $BashrcPath" -Level Info

    # Ensure bashrc exists
    if (-not (Test-Path $BashrcPath)) {
        if ($PSCmdlet.ShouldProcess($BashrcPath, "Create bashrc file")) {
            New-Item -ItemType File -Path $BashrcPath -Force | Out-Null
            Write-Log "Created new bashrc file: $BashrcPath" -Level Info
        }
    }

    # Read current content
    $currentContent = if (Test-Path $BashrcPath) {
        Get-Content $BashrcPath -Raw -ErrorAction SilentlyContinue
    }
    else {
        ''
    }

    if ([string]::IsNullOrEmpty($currentContent)) {
        $currentContent = ''
    }

    # Check if already configured
    $wasConfigured = $currentContent -match [regex]::Escape($script:ConfigMarkerStart)

    # Remove existing configuration if present
    $cleanedContent = Remove-ExistingConfiguration -Content $currentContent

    # Get new configuration
    $newConfig = Get-ShellConfiguration

    # Append new configuration
    $finalContent = $cleanedContent.TrimEnd() + "`n" + $newConfig

    if ($PSCmdlet.ShouldProcess($BashrcPath, "Update shell configuration")) {
        Set-Content -Path $BashrcPath -Value $finalContent -NoNewline
        Write-Log "Updated bashrc with Project Genie configuration" -Level Success
    }

    # Create backup
    $backupPath = "$BashrcPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    if ($PSCmdlet.ShouldProcess($backupPath, "Create backup")) {
        if ($currentContent) {
            Set-Content -Path $backupPath -Value $currentContent -NoNewline
            Write-Log "Backup created: $backupPath" -Level Info
        }
    }

    $configuredItems = @(
        'PATH additions (~/tools/bin, ~/.local/bin)',
        'Environment variables (SOPS_AGE_KEY_FILE, EDITOR)',
        'Shell functions (cdp, newproj)',
        'File listing aliases (ll, la, l)',
        'Navigation aliases (.., ..., ....)',
        'Git aliases (gs, gd, gds, gp, gps, glog)',
        'Docker aliases (dps, dpsa, di, dex, dlog)',
        'Directory bookmarks (proj, tools, docs)'
    )

    [PSCustomObject]@{
        Success          = $true
        Message          = "Shell configuration completed successfully"
        BashrcPath       = $BashrcPath
        BackupPath       = $backupPath
        WasReconfigured  = $wasConfigured
        AgeKeyPath       = $AgeKeyPath
        ConfiguredItems  = $configuredItems
        ReloadCommand    = "source $BashrcPath"
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
        Write-Log "To apply changes, run: $($Result.ReloadCommand)" -Level Info
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
