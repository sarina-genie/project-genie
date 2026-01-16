# Validation Guide

Procedures for validating PowerShell 7 scripts before deployment.

## Validation Levels

| Level | Type | When to Use |
|-------|------|-------------|
| L1 | Syntax | Every script, every change |
| L2 | Static Analysis | Before commit |
| L3 | Dry Run | Before first execution |
| L4 | Integration | Before deployment |

---

## Level 1: Syntax Validation

**Purpose:** Ensure script has no syntax errors.

### PowerShell Parser Check

```powershell
function Test-ScriptSyntax {
    param([string]$Path)
    
    $errors = $null
    $tokens = $null
    
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    
    if ($errors.Count -gt 0) {
        Write-Host "Syntax errors found in $Path" -ForegroundColor Red
        $errors | ForEach-Object {
            Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
        }
        return $false
    }
    
    Write-Host "Syntax OK: $Path" -ForegroundColor Green
    return $true
}

# Usage
Test-ScriptSyntax -Path ".\Script.ps1"
```

### Batch Validation

```powershell
# Validate all scripts in directory
Get-ChildItem -Path ".\scripts" -Filter "*.ps1" -Recurse | ForEach-Object {
    Test-ScriptSyntax -Path $_.FullName
}
```

---

## Level 2: Static Analysis (PSScriptAnalyzer)

**Purpose:** Check for best practice violations, potential bugs, and style issues.

### Installation

```powershell
# Install PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

### Basic Analysis

```powershell
# Analyse single script
Invoke-ScriptAnalyzer -Path ".\Script.ps1"

# Analyse with severity filter
Invoke-ScriptAnalyzer -Path ".\Script.ps1" -Severity Error, Warning

# Analyse entire directory
Invoke-ScriptAnalyzer -Path ".\scripts" -Recurse
```

### Custom Rules Configuration

Create `.PSScriptAnalyzerSettings.psd1`:

```powershell
@{
    Severity = @('Error', 'Warning')
    
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'  # We use Write-Host for coloured output
    )
    
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('7.0')
        }
        
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
        }
    }
}
```

### Run with Settings

```powershell
Invoke-ScriptAnalyzer -Path ".\Script.ps1" -Settings ".\.PSScriptAnalyzerSettings.psd1"
```

### Required Rules (Must Pass)

| Rule | Description |
|------|-------------|
| PSAvoidUsingPlainTextForPassword | Don't store passwords in plain text |
| PSAvoidUsingConvertToSecureStringWithPlainText | Use proper secure string handling |
| PSAvoidUsingInvokeExpression | Avoid Invoke-Expression (security risk) |
| PSUseShouldProcessForStateChangingFunctions | Use ShouldProcess for changes |
| PSAvoidGlobalVars | Don't pollute global scope |
| PSUseDeclaredVarsMoreThanAssignments | Use variables you declare |

---

## Level 3: Dry Run Testing

**Purpose:** Verify script behaviour without making changes.

### WhatIf Testing

```powershell
# Run script in WhatIf mode
.\Script.ps1 -WhatIf -Verbose

# Expected output shows what WOULD happen
# No actual changes are made
```

### Verbose Mode

```powershell
# See detailed execution flow
.\Script.ps1 -Verbose

# Combine with WhatIf for safe testing
.\Script.ps1 -WhatIf -Verbose
```

### Common Parameters Check

Verify script supports:
- `-WhatIf` - Preview changes
- `-Confirm` - Prompt before changes
- `-Verbose` - Detailed output
- `-Debug` - Debug output

```powershell
# Test that parameters exist
(Get-Command .\Script.ps1).Parameters.Keys -contains 'WhatIf'
(Get-Command .\Script.ps1).Parameters.Keys -contains 'Verbose'
```

---

## Level 4: Integration Testing

**Purpose:** Verify script works correctly in target environment.

### Pre-flight Checks

```powershell
function Test-PreflightChecks {
    param([string]$ScriptPath)
    
    $checks = @{
        'File exists' = { Test-Path $ScriptPath }
        'Has shebang (Linux)' = { 
            if ($IsLinux) {
                (Get-Content $ScriptPath -First 1) -match '^#!'
            } else { $true }
        }
        'Has requires statement' = {
            (Get-Content $ScriptPath -Raw) -match '#Requires -Version'
        }
        'Has CmdletBinding' = {
            (Get-Content $ScriptPath -Raw) -match '\[CmdletBinding'
        }
        'Has help documentation' = {
            (Get-Content $ScriptPath -Raw) -match '<#[\s\S]*\.SYNOPSIS[\s\S]*#>'
        }
    }
    
    $results = @()
    foreach ($check in $checks.GetEnumerator()) {
        $passed = try { & $check.Value } catch { $false }
        $results += [PSCustomObject]@{
            Check = $check.Key
            Passed = $passed
        }
    }
    
    return $results
}
```

### Environment Validation

```powershell
function Test-Environment {
    param()
    
    $checks = @{
        'PowerShell 7+' = { $PSVersionTable.PSVersion.Major -ge 7 }
        'Running on target OS' = { $IsLinux -or $IsWindows }  # Adjust as needed
        'Required modules' = { Get-Module -ListAvailable PSScriptAnalyzer }
    }
    
    # Run checks and report
    foreach ($check in $checks.GetEnumerator()) {
        $result = try { & $check.Value } catch { $false }
        $status = if ($result) { "✅" } else { "❌" }
        Write-Host "$status $($check.Key)"
    }
}
```

---

## Validation Script

Complete validation script to run all checks:

```powershell
#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate PowerShell scripts for the isolated dev environment.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".",
    
    [Parameter()]
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'

function Test-AllScripts {
    param([string]$BasePath)
    
    $scripts = Get-ChildItem -Path $BasePath -Filter "*.ps1" -Recurse
    $results = @()
    
    foreach ($script in $scripts) {
        Write-Host "`nValidating: $($script.Name)" -ForegroundColor Cyan
        
        # Level 1: Syntax
        $syntaxOK = Test-ScriptSyntax -Path $script.FullName
        
        # Level 2: PSScriptAnalyzer
        $analyzerResults = Invoke-ScriptAnalyzer -Path $script.FullName -Severity Error, Warning
        $analyzerOK = $analyzerResults.Count -eq 0
        
        if (-not $analyzerOK) {
            $analyzerResults | ForEach-Object {
                Write-Host "  $($_.Severity): $($_.Message) (Line $($_.Line))" -ForegroundColor Yellow
            }
        }
        
        # Level 3: Structure checks
        $structureOK = Test-ScriptStructure -Path $script.FullName
        
        $results += [PSCustomObject]@{
            Script = $script.Name
            Syntax = $syntaxOK
            Analyser = $analyzerOK
            Structure = $structureOK
            Overall = $syntaxOK -and $analyzerOK -and $structureOK
        }
    }
    
    return $results
}

function Test-ScriptStructure {
    param([string]$Path)
    
    $content = Get-Content $Path -Raw
    
    $checks = @(
        ($content -match '#Requires -Version 7'),
        ($content -match '\[CmdletBinding'),
        ($content -match '\.SYNOPSIS')
    )
    
    return ($checks | Where-Object { $_ }).Count -eq $checks.Count
}

# Main
$results = Test-AllScripts -BasePath $Path

Write-Host "`n`nValidation Summary" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

$results | Format-Table -AutoSize

$failed = $results | Where-Object { -not $_.Overall }
if ($failed) {
    Write-Host "`n$($failed.Count) script(s) failed validation" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`nAll scripts passed validation!" -ForegroundColor Green
    exit 0
}
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Validate PowerShell Scripts

on:
  push:
    paths:
      - '**.ps1'
  pull_request:
    paths:
      - '**.ps1'

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install PowerShell
        run: |
          sudo apt-get update
          sudo apt-get install -y powershell
      
      - name: Install PSScriptAnalyzer
        shell: pwsh
        run: Install-Module -Name PSScriptAnalyzer -Force
      
      - name: Run Validation
        shell: pwsh
        run: ./Test-Scripts.ps1 -Path ./scripts
```

---

## Checklist

Before marking a script as validated:

- [ ] Syntax check passes (Level 1)
- [ ] PSScriptAnalyzer shows no errors/warnings (Level 2)
- [ ] Script runs with `-WhatIf` without errors (Level 3)
- [ ] Script has proper help documentation
- [ ] Script uses `[CmdletBinding()]`
- [ ] Script has `#Requires -Version 7.0`
- [ ] Linux scripts have `#!/usr/bin/env pwsh` shebang
- [ ] Script returns structured objects, not raw text
- [ ] Error handling is implemented
- [ ] Sensitive data handling is secure
