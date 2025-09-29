<#
.SYNOPSIS
Safely list and optionally delete or move untracked files in a git repository.

.DESCRIPTION
This script uses `git ls-files --others --exclude-standard -z` to get a binary-safe
list of untracked files (so filenames with special characters are handled correctly).
It supports four modes:
 - Prompt  : interactive prompt asking whether to Delete or Move files to backup
 - Preview : only list untracked files (safe)
 - Delete  : delete all untracked files
 - Move    : move all untracked files to a backup folder (default: .untracked_backup)

USAGE
From the repository root (recommended):
  pwsh .\.scripts\clean-untracked.ps1 -Mode Preview
  pwsh .\.scripts\clean-untracked.ps1 -Mode Move -BackupDir .\.untracked_backup
  pwsh .\.scripts\clean-untracked.ps1           # interactive prompt

#>
param(
    [ValidateSet('Prompt','Preview','Delete','Move')]
    [string]$Mode = 'Prompt',

    [string]$BackupDir = '.untracked_backup'
)

function Write-Heading($s) { Write-Host "`n=== $s ===`n" -ForegroundColor Cyan }

# Ensure we are in the repo root so paths from git are correct
$gitRoot = (& git rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) {
    Write-Error "This script must be run inside a git repository."
    exit 2
}
Push-Location -LiteralPath $gitRoot

# Get null-delimited list of untracked files
$rawFile = [IO.Path]::GetTempFileName()
try {
    & git ls-files --others --exclude-standard -z > $rawFile
    $rawBytes = [System.IO.File]::ReadAllBytes($rawFile)
    $rawString = [System.Text.Encoding]::UTF8.GetString($rawBytes)
    $names = $rawString -split "`0" | Where-Object { $_ -ne '' }
} catch {
    Write-Error "Failed to list untracked files: $_"
    Pop-Location
    exit 3
} finally {
    if (Test-Path $rawFile) { Remove-Item -LiteralPath $rawFile -Force -ErrorAction SilentlyContinue }
}

if (-not $names -or $names.Count -eq 0) {
    Write-Host "No untracked files found. Working tree clean (or only ignored files present)."
    Pop-Location
    exit 0
}

Write-Heading "Untracked files ($($names.Count))"
$index = 0
foreach ($n in $names) {
    $index++
    Write-Host "[$index] $n"
}

if ($Mode -eq 'Preview') {
    Write-Host "Preview mode: no files changed."
    Pop-Location
    exit 0
}

# Confirm mode if interactive
if ($Mode -eq 'Prompt') {
    Write-Host "Options: [D]elete all untracked files, [M]ove to backup ($BackupDir), [C]ancel"
    $choice = Read-Host "Choose D, M, or C"
    switch ($choice.ToUpper()) {
        'D' { $Mode = 'Delete' }
        'M' { $Mode = 'Move' }
        default { Write-Host 'Cancelled.'; Pop-Location; exit 0 }
    }
}

if ($Mode -eq 'Move') {
    # Ensure backup dir exists
    if (-not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
    foreach ($n in $names) {
        try {
            $destPath = Join-Path $BackupDir $n
            # Create destination directory if needed
            $destDir = Split-Path -LiteralPath $destPath -Parent
            if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

            Move-Item -LiteralPath $n -Destination $destPath -Force -ErrorAction Stop
            Write-Host "Moved: $n -> $destPath"
        } catch {
            Write-Warning "Failed to move $n : $_"
        }
    }
    Write-Heading "Finished move operation"
    & git status --porcelain
    Pop-Location
    exit 0
}

if ($Mode -eq 'Delete') {
    Write-Host "About to delete $($names.Count) untracked files. This cannot be undone."
    $confirm = Read-Host "Type 'yes' to confirm deletion"
    if ($confirm -ne 'yes') {
        Write-Host 'Aborted by user.'
        Pop-Location
        exit 0
    }
    foreach ($n in $names) {
        try {
            Remove-Item -LiteralPath $n -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted: $n"
        } catch {
            Write-Warning "Failed to delete $n : $_"
        }
    }
    Write-Heading "Finished delete operation"
    & git status --porcelain
    Pop-Location
    exit 0
}

# Should not reach here
Pop-Location
exit 0
