#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Move Entra ID configuration exports from diff folder to Maester custom tests location.

.DESCRIPTION
    This script moves all files from ./diff/ to ../../tests/maester/Custom/ for Maester
    configuration testing and validation. Preserves folder structure during move.

.EXAMPLE
    PS> .\move-diff.ps1

    Moves all diff files to Maester custom location and shows summary
#>

param(
    [string]$SourcePath = "diff",
    [string]$DestinationPath = "../../tests/maester/Custom/diff",
    [switch]$KeepSource
)

Write-Host "`n📁 Entra ID Configuration Export Mover" -ForegroundColor Cyan
Write-Host "=====================================`n" -ForegroundColor Cyan

# Resolve source path
if (-not (Test-Path $SourcePath)) {
    Write-Host "✗ Source directory '$SourcePath' not found" -ForegroundColor Red
    exit 1
}

$sourceFullPath = (Resolve-Path $SourcePath).Path

# Resolve or create destination path
Write-Host "🔍 Checking destination path..." -ForegroundColor Cyan

if (Test-Path $DestinationPath) {
    $destFullPath = (Resolve-Path $DestinationPath).Path
    Write-Host "✓ Destination path exists: $destFullPath" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Destination path does not exist: $DestinationPath" -ForegroundColor Yellow

    # Try to create the destination path
    try {
        Write-Host "📂 Creating destination directory structure..." -ForegroundColor Cyan
        $destFullPath = (New-Item -ItemType Directory -Path $DestinationPath -Force -ErrorAction Stop).FullName
        Write-Host "✓ Created destination: $destFullPath" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create destination path: $_" -ForegroundColor Red
        exit 1
    }
}

# Get count of files to move
$filesToMove = @(Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue)
$folderCount = @(Get-ChildItem -Path $SourcePath -Recurse -Directory -ErrorAction SilentlyContinue).Count

if ($filesToMove.Count -eq 0) {
    Write-Host "⚠️  No files found in '$SourcePath'" -ForegroundColor Yellow
    exit 0
}

Write-Host "📊 Source: $SourcePath" -ForegroundColor Gray
Write-Host "   Files:      $($filesToMove.Count)" -ForegroundColor Gray
Write-Host "   Folders:    $folderCount" -ForegroundColor Gray
Write-Host ""
Write-Host "📍 Destination: $DestinationPath" -ForegroundColor Gray
Write-Host ""

# Ask for confirmation
Write-Host ""
$confirm = Read-Host "Do you want to move these files? (Y/N)"

if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "❌ Operation cancelled" -ForegroundColor Yellow
    exit 0
}

# Move files with folder structure preserved
Write-Host "`n🚚 Moving files..." -ForegroundColor Cyan

$movedCount = 0
$failedCount = 0

foreach ($file in $filesToMove) {
    # Calculate relative path to preserve folder structure
    $relativePath = $file.FullName.Substring($sourceFullPath.Length).TrimStart('\')
    $destFilePath = Join-Path $DestinationPath $relativePath
    $destFileDir = Split-Path -Parent $destFilePath

    # Create subdirectories if needed
    if (-not (Test-Path $destFileDir)) {
        New-Item -ItemType Directory -Path $destFileDir -Force | Out-Null
    }

    # Move the file
    try {
        Move-Item -Path $file.FullName -Destination $destFilePath -Force -ErrorAction Stop
        Write-Host "   ✓ Moved: $relativePath" -ForegroundColor Green
        $movedCount++
    }
    catch {
        Write-Host "   ✗ Failed: $relativePath - $_" -ForegroundColor Red
        $failedCount++
    }
}

# Clean up empty source directory if no errors and not keeping source
if ($failedCount -eq 0 -and -not $KeepSource) {
    try {
        $remainingFiles = @(Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($remainingFiles -eq 0) {
            Write-Host "`n🗑️  Cleaning up empty source directory..." -ForegroundColor Cyan
            Remove-Item -Path $SourcePath -Recurse -Force -ErrorAction Stop
            Write-Host "✓ Removed empty '$SourcePath' directory" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️  Could not remove source directory: $_" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n📋 Move Summary" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host "✓ Successfully moved:  $movedCount file(s)" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "✗ Failed:              $failedCount file(s)" -ForegroundColor Red
}
Write-Host ""

# Show destination structure
Write-Host "📂 Destination folder structure:" -ForegroundColor Cyan
Get-ChildItem -Path $DestinationPath -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $relativePath = $_.FullName.Substring((Resolve-Path $DestinationPath).Path.Length).TrimStart('\')
    $depth = ($relativePath | Select-String -Pattern '\\' -AllMatches).Matches.Count
    $indent = "   " * ($depth + 1)
    $fileCount = @(Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count
    Write-Host "$indent├─ $($_.Name) ($fileCount files)" -ForegroundColor Gray
} | Select-Object -First 10

# Show file count in destination
$destFiles = @(Get-ChildItem -Path $DestinationPath -Recurse -File -ErrorAction SilentlyContinue).Count
Write-Host "`n📊 Total files in destination: $destFiles" -ForegroundColor Gray

Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Files are ready for Maester testing in '$DestinationPath'" -ForegroundColor Gray
Write-Host "   2. Run Maester tests against the configuration exports" -ForegroundColor Gray
Write-Host "   3. Review test results for compliance and drift detection" -ForegroundColor Gray
