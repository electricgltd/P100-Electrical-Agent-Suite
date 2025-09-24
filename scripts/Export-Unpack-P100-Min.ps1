[CmdletBinding()]
param(
  [string]$SolutionName = 'DesignAndCosting',
  [string]$TenantId     = 'af9de730-17d2-4056-b1bc-76b39ab34ac7',
  [string]$AppId        = 'e0d9eb46-a46d-46f1-b89d-38f567c450e7',
  [string]$DevUrl       = 'https://org8e8ad840.crm11.dynamics.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info { param($m) Write-Host $m -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }

# 1) Get secret securely (masked)
$sec = Read-Host -Prompt 'Enter Client Secret' -AsSecureString
$ClientSecret = [System.Net.NetworkCredential]::new('', $sec).Password

# 2) Ensure PAC (best effort)
if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
  Write-Info "📦 Installing Power Platform CLI via winget (if available)..."
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install Microsoft.PowerPlatformCLI --silent --accept-source-agreements --accept-package-agreements | Out-Null
  }
  if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    throw "PAC not found. Install: https://aka.ms/PowerAppsCLI"
  }
}

# 3) Auth + select env
Write-Info "`n🔐 Authenticating..."
pac auth clear | Out-Null
pac auth create --tenant $TenantId --applicationId $AppId --clientSecret $ClientSecret --url $DevUrl | Out-Null

Write-Info "🌐 Selecting active environment..."
pac org select --environment $DevUrl | Out-Null

Write-Info "🔎 Verifying (pac org who)..."
pac org who

# 4) Export unmanaged
$Temp = Join-Path (Get-Location) '_temp'
if (-not (Test-Path $Temp)) { New-Item -ItemType Directory -Path $Temp | Out-Null }

Write-Info "`n📦 Exporting solution '$SolutionName' (unmanaged)..."
pac solution export --environment $DevUrl --name $SolutionName --path $Temp --managed false

# 5) Find ZIP
$Zip = Join-Path $Temp "$SolutionName.zip"
if (-not (Test-Path $Zip)) {
  $latest = Get-ChildItem -Path $Temp -Filter *.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { throw "❌ No ZIPs found in $Temp after export." }
  $Zip = $latest.FullName
  Write-Warn "ℹ️ Using detected export: $Zip"
}

# 6) Unpack
$SolutionFolder = Join-Path (Get-Location) ("solutions\" + $SolutionName)
if (-not (Test-Path $SolutionFolder)) { New-Item -ItemType Directory -Path $SolutionFolder | Out-Null }

Write-Info "🗂  Unpacking to $SolutionFolder ..."
pac solution unpack --zipfile $Zip --folder $SolutionFolder --packagetype Unmanaged

Write-OK "`n✅ Done. Folder ready for source control: $SolutionFolder"
