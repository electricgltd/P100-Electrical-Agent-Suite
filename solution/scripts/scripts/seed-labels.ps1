<#
.SYNOPSIS
  Seed GitHub repository labels from .github/labels.yml

.PARAMETER Owner
  Repository owner (organization or user)

.PARAMETER Repo
  Repository name

.PARAMETER Path
  Path to labels YAML (default: ./.github/labels.yml)

.PARAMETER DryRun
  If present, print actions but don't call gh

This script is idempotent and safe to re-run.
#>

param(
  [string]$Owner = 'electricgltd',
  [string]$Repo  = 'P100-Electrical-Agent-Suite',
  [string]$Path  = '.github/labels.yml',
  [switch]$DryRun
)

function Test-GhInstalled {
  param()
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI 'gh' is required. Install from https://cli.github.com/"
    exit 2
  }
}

Test-GhInstalled

if (-not (Test-Path $Path)) {
  Write-Error "Labels file not found: $Path"
  exit 2
}

try {
  $yaml = Get-Content $Path -Raw | ConvertFrom-Yaml
} catch {
  Write-Error "Failed to parse YAML: $_"
  exit 3
}

if (-not $yaml.labels) {
  Write-Error "No 'labels' key found in $Path"
  exit 4
}

foreach ($lbl in $yaml.labels) {
  $name = $lbl.name
  $color = $lbl.color
  $desc = $lbl.description

  # Check if label exists
  $escaped = [uri]::EscapeDataString($name)
  $exists = & gh api repos/$Owner/$Repo/labels/$escaped --jq '.' 2>$null
  if ($LASTEXITCODE -eq 0 -and $exists) {
    Write-Host "Exists: $name"
    continue
  }

  if ($DryRun) {
    Write-Host "DRY RUN: Would create label: $name (color: $color)"
  } else {
    Write-Host "Creating: $name"
    $out = & gh api repos/$Owner/$Repo/labels -f name="$name" -f color="$color" -f description="$desc" 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Failed to create ${name}: $out"
    }
  }
}

Write-Host "Done."
