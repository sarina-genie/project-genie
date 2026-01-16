#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Create a new project from a template.

.DESCRIPTION
    Creates a new project by:
    - Validating the specified template exists
    - Copying template to ~/projects/$Category/$ProjectName
    - Replacing placeholders ({{PROJECT_NAME}}, {{DATE}}, etc.)
    - Initializing a git repository
    - Creating an initial commit

    This script does not require root privileges.

.PARAMETER ProjectName
    Name of the new project to create.

.PARAMETER Template
    Template to use. Valid options: python-tier1, python-tier2, typescript-tier2, fullstack-tier3

.PARAMETER Category
    Project category/directory. Valid options: agents, web, devops, experiments

.PARAMETER TemplateDir
    Base directory containing templates. Defaults to ~/projects/_templates.

.PARAMETER WhatIf
    Shows what would happen if the script runs. No changes are made.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.EXAMPLE
    PS> ./New-Project.ps1 -ProjectName "my-api" -Template "python-tier1" -Category "web"
    Creates a new Python Tier 1 project in ~/projects/web/my-api

.EXAMPLE
    PS> ./New-Project.ps1 -ProjectName "agent-test" -Template "python-tier2" -Category "agents"
    Creates a new Python Tier 2 project for agents.

.EXAMPLE
    PS> ./New-Project.ps1 -ProjectName "my-app" -Template "fullstack-tier3" -Category "web" -WhatIf
    Shows what would be created without making changes.

.NOTES
    Author: Project Genie
    Version: 1.0.0
    Created: 2026-01-16

    Prerequisites:
    - PowerShell 7.0 or higher
    - Git installed
    - Template directory with templates

    Change Log:
    1.0.0 - Initial release
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the new project")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z][a-zA-Z0-9_-]*$')]
    [string]$ProjectName,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Template to use")]
    [ValidateSet('python-tier1', 'python-tier2', 'typescript-tier2', 'fullstack-tier3')]
    [string]$Template,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Project category")]
    [ValidateSet('agents', 'web', 'devops', 'experiments')]
    [string]$Category,

    [Parameter(Mandatory = $false, HelpMessage = "Base directory for templates")]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateDir = "$HOME/projects/_templates"
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
        [string]$WorkingDirectory
    )

    Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug

    $originalLocation = Get-Location

    try {
        if ($WorkingDirectory) {
            Set-Location $WorkingDirectory
        }

        $result = & $Command @Arguments 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: $result"
        }

        if ($PassThru) {
            return $result
        }
    }
    finally {
        Set-Location $originalLocation
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

function Test-TemplateExists {
    [CmdletBinding()]
    param()

    $templatePath = Join-Path $TemplateDir $Template

    if (-not (Test-Path $templatePath)) {
        # Check if template dir exists at all
        if (-not (Test-Path $TemplateDir)) {
            throw "Template directory does not exist: $TemplateDir. Run Setup-FileSystem.ps1 first."
        }

        $available = Get-ChildItem -Path $TemplateDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $availableStr = if ($available) { $available -join ', ' } else { 'none' }

        throw "Template '$Template' not found in $TemplateDir. Available templates: $availableStr"
    }

    Write-Log "Template found: $templatePath" -Level Debug
    return $templatePath
}

function Copy-Template {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    if (Test-Path $DestinationPath) {
        throw "Project already exists: $DestinationPath"
    }

    if ($PSCmdlet.ShouldProcess($DestinationPath, "Copy template from $SourcePath")) {
        # Create parent directory if needed
        $parentDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Copy template
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force
        Write-Log "Copied template to $DestinationPath" -Level Info

        return $true
    }

    return $false
}

function Update-Placeholders {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ProjectPath
    )

    $placeholders = @{
        '{{PROJECT_NAME}}' = $ProjectName
        '{{PROJECT_NAME_SNAKE}}' = ($ProjectName -replace '-', '_')
        '{{PROJECT_NAME_PASCAL}}' = (Get-Culture).TextInfo.ToTitleCase($ProjectName) -replace '[-_]', ''
        '{{DATE}}' = Get-Date -Format 'yyyy-MM-dd'
        '{{YEAR}}' = Get-Date -Format 'yyyy'
        '{{CATEGORY}}' = $Category
        '{{TEMPLATE}}' = $Template
        '{{AUTHOR}}' = $(git config user.name 2>$null) ?? 'Unknown'
        '{{EMAIL}}' = $(git config user.email 2>$null) ?? 'unknown@example.com'
    }

    $replacedFiles = @()

    # Get all text files
    $textExtensions = @('*.py', '*.js', '*.ts', '*.tsx', '*.json', '*.yaml', '*.yml', '*.md', '*.txt', '*.toml', '*.cfg', '*.ini', '*.sh', '*.ps1', '*.html', '*.css', '*.env*', 'Dockerfile*', 'Makefile', '*.lock')

    $files = foreach ($ext in $textExtensions) {
        Get-ChildItem -Path $ProjectPath -Filter $ext -Recurse -File -ErrorAction SilentlyContinue
    }

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

        if ([string]::IsNullOrEmpty($content)) {
            continue
        }

        $modified = $false
        $newContent = $content

        foreach ($placeholder in $placeholders.GetEnumerator()) {
            if ($newContent -match [regex]::Escape($placeholder.Key)) {
                $newContent = $newContent -replace [regex]::Escape($placeholder.Key), $placeholder.Value
                $modified = $true
            }
        }

        if ($modified) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Replace placeholders")) {
                Set-Content -Path $file.FullName -Value $newContent -NoNewline
                $replacedFiles += $file.Name
                Write-Log "Updated placeholders in: $($file.Name)" -Level Debug
            }
        }
    }

    # Rename files with PROJECT_NAME in filename
    $filesToRename = Get-ChildItem -Path $ProjectPath -Recurse -File | Where-Object { $_.Name -match '{{PROJECT_NAME}}' }

    foreach ($file in $filesToRename) {
        $newName = $file.Name -replace '{{PROJECT_NAME}}', $ProjectName
        $newPath = Join-Path $file.DirectoryName $newName

        if ($PSCmdlet.ShouldProcess($file.FullName, "Rename to $newName")) {
            Rename-Item -Path $file.FullName -NewName $newName
            Write-Log "Renamed: $($file.Name) -> $newName" -Level Debug
        }
    }

    return $replacedFiles
}

function Initialize-GitRepo {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ProjectPath
    )

    if ($PSCmdlet.ShouldProcess($ProjectPath, "Initialize git repository")) {
        # Initialize repo
        Invoke-NativeCommand -Command 'git' -Arguments @('init') -WorkingDirectory $ProjectPath
        Write-Log "Initialized git repository" -Level Info

        # Add all files
        Invoke-NativeCommand -Command 'git' -Arguments @('add', '.') -WorkingDirectory $ProjectPath

        # Create initial commit
        $commitMessage = "Initial commit from $Template template"
        Invoke-NativeCommand -Command 'git' -Arguments @('commit', '-m', $commitMessage) -WorkingDirectory $ProjectPath
        Write-Log "Created initial commit" -Level Info

        return $true
    }

    return $false
}

function Invoke-MainLogic {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Creating new project: $ProjectName" -Level Info
    Write-Log "Template: $Template, Category: $Category" -Level Info

    # Validate template exists
    $templatePath = Test-TemplateExists

    # Calculate destination
    $projectPath = Join-Path $HOME "projects" $Category $ProjectName
    Write-Log "Destination: $projectPath" -Level Info

    # Copy template
    $copied = Copy-Template -SourcePath $templatePath -DestinationPath $projectPath

    if (-not $copied -and -not $WhatIfPreference) {
        throw "Failed to copy template"
    }

    # Replace placeholders
    $replacedFiles = @()
    if ($copied -or $WhatIfPreference) {
        $replacedFiles = Update-Placeholders -ProjectPath $projectPath
    }

    # Initialize git
    $gitInitialized = $false
    if ($copied -or $WhatIfPreference) {
        $gitInitialized = Initialize-GitRepo -ProjectPath $projectPath
    }

    [PSCustomObject]@{
        Success         = $true
        Message         = "Project created successfully"
        ProjectName     = $ProjectName
        ProjectPath     = $projectPath
        Template        = $Template
        Category        = $Category
        FilesUpdated    = $replacedFiles
        GitInitialized  = $gitInitialized
        NextSteps       = @(
            "cd $projectPath",
            "Review and update README.md",
            "Install dependencies",
            "Start coding!"
        )
        Timestamp       = Get-Date
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
        Write-Log "Project created at: $($Result.ProjectPath)" -Level Info
        Write-Log "Next: cd $($Result.ProjectPath)" -Level Info
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
