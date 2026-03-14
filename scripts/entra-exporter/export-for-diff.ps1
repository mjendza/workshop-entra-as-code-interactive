#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Export Entra ID configuration using EntraExporter and organize files with baseline/current prefixes for diff comparison.

.DESCRIPTION
    This script:
    1. Runs EntraExporter to export Entra ID configuration to the 'diff' folder
    2. Recursively renames ALL exported files (in all subdirectories) with prefixes:
       - First run: Prefixes all files with 'baseline-' (no current baseline files exist)
       - Subsequent runs: Prefixes all files with 'current-' (for comparison with baseline)
    3. Skips files that already have 'baseline-' or 'current-' prefix
    4. Preserves folder structure but adds prefix to each filename

.EXAMPLE
    PS> .\export-for-diff.ps1

    First run: Creates diff/*/baseline-*.json files (all subdirectories)
    Second run: Creates diff/*/current-*.json files for comparison
#>

param(
    [string]$DiffPath = "diff",
    [ValidateSet("baseline", "current", "auto")]
    [string]$Prefix = "auto"
)

# Ensure diff directory exists
if (-not (Test-Path $DiffPath)) {
    New-Item -ItemType Directory -Path $DiffPath -Force | Out-Null
    Write-Host "✓ Created '$DiffPath' directory" -ForegroundColor Green
}
else {
    # If diff directory exists, ask if user wants to clean it
    $existingFiles = @(Get-ChildItem -Path $DiffPath -Recurse -File -ErrorAction SilentlyContinue).Count

    if ($existingFiles -gt 0) {
        Write-Host "`n⚠️  Found $existingFiles file(s) in '$DiffPath' directory" -ForegroundColor Yellow
        $cleanChoice = Read-Host "Do you want to clean the '$DiffPath' folder before export? (Y/N)"

        if ($cleanChoice -eq "Y" -or $cleanChoice -eq "y") {
            Write-Host "`n🗑️  Cleaning '$DiffPath' directory..." -ForegroundColor Cyan
            Remove-Item -Path "$DiffPath/*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Cleaned: All files removed" -ForegroundColor Green
        }
        else {
            Write-Host "⏭️  Skipping cleanup - keeping existing files" -ForegroundColor Gray
        }
    }
}

# Check if baseline files already exist (determines if this is first or subsequent run)
$existingBaseline = @(Get-ChildItem -Path $DiffPath -Recurse -Filter "baseline-*" -File -ErrorAction SilentlyContinue).Count

Write-Host "`n📊 Running EntraExporter to export fresh Entra ID configuration..." -ForegroundColor Cyan

# Remove any existing unprefixed files before new export (cleanup old exports)
$unprefixedBefore = @(Get-ChildItem -Path $DiffPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "^(baseline|current)-" })

if ($unprefixedBefore.Count -gt 0) {
    Write-Host "   Cleaning up $($unprefixedBefore.Count) old unprefixed file(s)..." -ForegroundColor Gray
    foreach ($file in $unprefixedBefore) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Run EntraExporter to export fresh Entra ID configuration
try {
    Export-Entra -Path $DiffPath -Type "Config"
    Write-Host "✓ EntraExporter completed and files written to '$DiffPath'" -ForegroundColor Green
}
catch {
    Write-Host "✗ Export failed: $_" -ForegroundColor Red
    exit 1
}

# Determine prefix to use (auto mode)
if ($Prefix -eq "auto") {
    if ($existingBaseline -eq 0) {
        $Prefix = "baseline"
        Write-Host "`n📋 First run detected (no baseline files exist)" -ForegroundColor Yellow
        Write-Host "   Using 'baseline-' prefix for exported files" -ForegroundColor Yellow
    }
    else {
        $Prefix = "current"
        Write-Host "`n📋 Subsequent run detected (baseline files exist)" -ForegroundColor Yellow
        Write-Host "   Using 'current-' prefix for exported files" -ForegroundColor Yellow
    }
}

# Get all files recursively that don't already have baseline- or current- prefix
Write-Host "`n🔍 Scanning '$DiffPath' for unprefixed files (recursive)..." -ForegroundColor Cyan

$files = @(Get-ChildItem -Path $DiffPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "^(baseline|current)-" })

if ($files.Count -eq 0) {
    Write-Host "`n✓ No unprefixed files to rename (all files already have baseline- or current- prefix)" -ForegroundColor Green
    exit 0
}

Write-Host "   Found $($files.Count) unprefixed file(s) across all subdirectories" -ForegroundColor Gray

# Rename files with appropriate prefix (preserving directory structure)
Write-Host "`n🔤 Renaming files with '$Prefix-' prefix..." -ForegroundColor Cyan
$renamed = 0

foreach ($file in $files) {
    $newName = "$Prefix-$($file.Name)"
    $oldPath = $file.FullName
    $newPath = Join-Path $file.DirectoryName $newName

    try {
        Rename-Item -Path $oldPath -NewName $newName -Force
        $relativePath = $file.DirectoryName -replace [regex]::Escape((Resolve-Path $DiffPath).Path), "."
        Write-Host "  ✓ $relativePath/$($file.Name) → $newName" -ForegroundColor Green
        $renamed++
    }
    catch {
        Write-Host "  ✗ Failed to rename $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`n✓ Renaming complete: $renamed file(s) renamed with '$Prefix-' prefix" -ForegroundColor Green

# Summary - count files recursively by prefix
Write-Host "`n📁 Summary of '$DiffPath' directory (recursive):" -ForegroundColor Cyan

$allFiles = @(Get-ChildItem -Path $DiffPath -Recurse -File -ErrorAction SilentlyContinue)

if ($allFiles.Count -gt 0) {
    $baselineCount = @($allFiles | Where-Object { $_.Name -match "^baseline-" }).Count
    $currentCount = @($allFiles | Where-Object { $_.Name -match "^current-" }).Count
    $unprefixedCount = @($allFiles | Where-Object { $_.Name -notmatch "^(baseline|current)-" }).Count

    Write-Host "   Baseline files: $baselineCount" -ForegroundColor Green
    Write-Host "   Current files:  $currentCount" -ForegroundColor Yellow
    Write-Host "   Unprefixed:     $unprefixedCount" -ForegroundColor Gray
}

# Show directory structure
Write-Host "`n📂 Folder structure:" -ForegroundColor Cyan
Get-ChildItem -Path $DiffPath -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Resolve-Path $DiffPath).Path), ""
    $depth = ($relativePath | Select-String -Pattern '\\' -AllMatches).Matches.Count
    $indent = "  " * $depth
    $fileCount = @(Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count
    Write-Host "$indent├─ $($_.Name) ($fileCount files)" -ForegroundColor Gray
}

Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
if ($Prefix -eq "baseline") {
    Write-Host "   1. Review baseline-*.* files in the '$DiffPath' folder (all subdirectories)" -ForegroundColor Gray
    Write-Host "   2. Make changes to your Entra ID configuration" -ForegroundColor Gray
    Write-Host "   3. Run this script again to capture current state and see differences" -ForegroundColor Gray
}
else {
    Write-Host "`n📊 Comparing baseline vs current configurations..." -ForegroundColor Cyan

    # Function to compare two JSON files
    function Compare-JsonFiles {
        param(
            [string]$BaselineFile,
            [string]$CurrentFile
        )

        try {
            $baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
            $current = Get-Content $CurrentFile -Raw | ConvertFrom-Json

            # Simple comparison
            if ($baseline | ConvertTo-Json -Depth 100 -eq $current | ConvertTo-Json -Depth 100) {
                return $null
            }
            else {
                return @{
                    Baseline = $baseline
                    Current = $current
                    Changed = $true
                }
            }
        }
        catch {
            return $null
        }
    }

    # Find all baseline files and compare with current
    $baselineFiles = @(Get-ChildItem -Path $DiffPath -Recurse -Filter "baseline-*" -File)
    $differences = @()

    foreach ($baselineFile in $baselineFiles) {
        $currentFileName = $baselineFile.Name -replace "^baseline-", "current-"
        $currentFile = Join-Path $baselineFile.DirectoryName $currentFileName

        if (Test-Path $currentFile) {
            $comparison = Compare-JsonFiles $baselineFile.FullName $currentFile
            if ($comparison -and $comparison.Changed) {
                $relativePath = $baselineFile.DirectoryName -replace [regex]::Escape((Resolve-Path $DiffPath).Path), "."
                $differences += @{
                    File = "$relativePath/$($baselineFile.Name -replace '^baseline-', '')"
                    BaselinePath = $baselineFile.FullName
                    CurrentPath = $currentFile
                }
            }
        }
    }

    if ($differences.Count -eq 0) {
        Write-Host "`n✓ No differences found between baseline and current configurations!" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️  Found $($differences.Count) file(s) with configuration changes:" -ForegroundColor Yellow
        foreach ($diff in $differences) {
            Write-Host "   ⚡ $($diff.File)" -ForegroundColor Yellow
        }

        Write-Host "`n📋 Detailed comparison:" -ForegroundColor Cyan
        foreach ($diff in $differences) {
            Write-Host "`n  File: $($diff.File)" -ForegroundColor Yellow

            # Use PowerShell's Compare-Object for detailed diff
            $baselineContent = Get-Content $diff.BaselinePath -Raw
            $currentContent = Get-Content $diff.CurrentPath -Raw

            # Show side-by-side or detailed comparison
            $baselineLines = $baselineContent -split "`n"
            $currentLines = $currentContent -split "`n"

            $comparison = Compare-Object -ReferenceObject $baselineLines -DifferenceObject $currentLines -PassThru
            if ($comparison) {
                Write-Host "    Changes detected:" -ForegroundColor Gray
                $comparison | ForEach-Object {
                    if ($_.SideIndicator -eq "=>") {
                        Write-Host "      + $_" -ForegroundColor Green
                    }
                    else {
                        Write-Host "      - $_" -ForegroundColor Red
                    }
                } | Select-Object -First 5  # Show first 5 differences
            }
        }

        Write-Host "`n💾 Review detailed changes:" -ForegroundColor Cyan
        Write-Host "   Use your favorite diff tool (VS Code, WinMerge, etc.) on:" -ForegroundColor Gray
        foreach ($diff in $differences | Select-Object -First 3) {
            Write-Host "      baseline: $($diff.BaselinePath)" -ForegroundColor Gray
            Write-Host "      current:  $($diff.CurrentPath)" -ForegroundColor Gray
        }
    }
}
