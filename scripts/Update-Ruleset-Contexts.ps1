param(
  [Parameter(Mandatory=$false)][string]$Owner = 'electricgltd',
  [Parameter(Mandatory=$false)][string]$Repo = 'P100-Electrical-Agent-Suite',
  [Parameter(Mandatory=$false)][string]$RulesetName = 'DoctorGPhD',
  [Parameter(Mandatory=$false)][string[]]$Contexts = @('status: completed','status: expected','status: pending','status: queued','status: waiting'),
  [Parameter(Mandatory=$false)][string]$OutDir = '_temp'
)

$ErrorActionPreference = 'Stop'

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' not found in PATH. Please install it."
  }
}

Require-Command 'gh'
Require-Command 'git'

Write-Host "Owner: $Owner; Repo: $Repo; Ruleset: $RulesetName" -ForegroundColor Cyan

# Fetch rulesets and locate the target
$rulesetsJson = gh api "repos/$Owner/$Repo/rulesets"
$rulesets = $rulesetsJson | ConvertFrom-Json
$ruleset = $rulesets | Where-Object { $_.name -eq $RulesetName }
if (-not $ruleset) {
  throw "Ruleset '$RulesetName' not found in $Owner/$Repo."
}
$rulesetId = $ruleset.id
Write-Host "Found ruleset id: $rulesetId" -ForegroundColor Green

# Prepare output paths
$currentPath = Join-Path $OutDir 'ruleset-current.json'
$updatedPath = Join-Path $OutDir 'ruleset-updated.json'
New-Item -ItemType Directory -Force -Path (Split-Path $currentPath) | Out-Null

# Get current ruleset JSON
(gh api "repos/$Owner/$Repo/rulesets/$rulesetId") | Out-File -Encoding utf8 $currentPath
$json = Get-Content $currentPath -Raw | ConvertFrom-Json -Depth 100

# Ensure a required_status_checks rule exists
$rsc = $json.rules | Where-Object { $_.type -eq 'required_status_checks' }
if (-not $rsc) {
  $rsc = [pscustomobject]@{
    type       = 'required_status_checks'
    parameters = [pscustomobject]@{
      strict   = $false
      contexts = @()
    }
  }
  $json.rules += $rsc
}

# Merge contexts uniquely
$merged = @($rsc.parameters.contexts + $Contexts) | Sort-Object -Unique
$rsc.parameters.contexts = $merged

# Save updated JSON
$json | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 $updatedPath

# Show diff (best effort)
try {
  Write-Host '----- DIFF (git diff --no-index) -----' -ForegroundColor Yellow
  git --no-pager diff --no-index -- $currentPath $updatedPath 2>$null
  Write-Host '----- END DIFF -----' -ForegroundColor Yellow
} catch {
  Write-Warning 'Could not display diff.'
}

# Apply the patch
Write-Host 'Patching ruleset via GitHub API...' -ForegroundColor Cyan
$null = gh api --method PATCH -H "Content-Type: application/json" "repos/$Owner/$Repo/rulesets/$rulesetId" --input $updatedPath
Write-Host 'Ruleset updated successfully.' -ForegroundColor Green
