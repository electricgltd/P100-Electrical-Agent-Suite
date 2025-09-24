<#
  Export-Unpack-P100.ps1
  Purpose: Authenticate → Select environment → Export solution → Unpack into solutions folder (hardened)
#>

[CmdletBinding()]
param(
  [string]$SolutionName = 'DesignAndCosting',
  [string]$TargetName   = 'P100-PowerPlatform-ALM',   # Credential Manager target for AppId + ClientSecret
  [string]$DevUrl       = 'https://org8e8ad840.crm11.dynamics.com',  # Dev & Test are same
  [string]$TenantId     = ''  # Optional: override TenantId here; else CredMan → env var → prompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSStyle) { $PSStyle.OutputRendering = 'Host' } # Avoid ANSI when redirecting output

# ── Utilities ─────────────────────────────────────────────────────────────────
function Write-Info    { param($m) Write-Host $m -ForegroundColor Cyan }
function Write-OK      { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-ErrLine { param($m) Write-Host $m -ForegroundColor Red }

# Ensure TLS 1.2 (best effort)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

# ── Native CredRead P/Invoke (namespaced) + helper that uses generic marshalling ──
Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Native {
  public static class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CREDENTIAL {
      public UInt32 Flags;
      public UInt32 Type;
      public string TargetName;
      public string Comment;
      public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
      public UInt32 CredentialBlobSize;
      public IntPtr CredentialBlob;
      public UInt32 Persist;
      public UInt32 AttributeCount;
      public IntPtr Attributes;
      public string TargetAlias;
      public string UserName;
    }
    [DllImport("Advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string target, uint type, uint reservedFlag, out IntPtr CredentialPtr);
    [DllImport("Advapi32.dll", SetLastError=true)]
    public static extern void CredFree(IntPtr cred);
  }

  public static class CredUtil {
    // Tries Generic (1) then Domain Password (2). Returns true if found.
    public static bool TryRead(string target, out string user, out string secret, out uint typeRead) {
      user = null; secret = null; typeRead = 0;
      IntPtr ptr;
      foreach (var t in new uint[] { 1u, 2u }) {
        if (CredMan.CredRead(target, t, 0, out ptr)) {
          try {
            var cred = Marshal.PtrToStructure<CredMan.CREDENTIAL>(ptr);
            user = cred.UserName;
            if (cred.CredentialBlob != IntPtr.Zero && cred.CredentialBlobSize > 0) {
              secret = Marshal.PtrToStringUni(cred.CredentialBlob, (int)cred.CredentialBlobSize / 2);
            } else {
              secret = string.Empty;
            }
            typeRead = t;
            return true;
          } finally {
            CredMan.CredFree(ptr);
          }
        }
      }
      return false;
    }
  }
}
"@

# ── Secure retrieval that supports both Generic & DomainPassword ───────────────
function Get-CredentialManagerSecret {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Target)

  $user = $null; $secret = $null; $typeRead = [uint32]0
  if ([Native.CredUtil]::TryRead($Target, [ref]$user, [ref]$secret, [ref]$typeRead)) {
    $typeName = if ($typeRead -eq 1) { 'Generic' } else { 'DomainPassword' }
    return @{ User = $user; Secret = $secret; Type = $typeName }
  }
  return $null
}

function Test-PacInstalled {
  $pac = Get-Command pac -ErrorAction SilentlyContinue
  if ($pac) { Write-OK "✅ Power Platform CLI found."; return }
  Write-Info "📦 Installing Power Platform CLI via winget..."
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw "winget is not available. Install PAC manually: https://aka.ms/PowerAppsCLI"
  }
  winget install Microsoft.PowerPlatformCLI --silent --accept-source-agreements --accept-package-agreements | Out-Null
  if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    throw "PAC did not install correctly. Install manually: https://aka.ms/PowerAppsCLI"
  }
  Write-OK "✅ Power Platform CLI installed."
}

function Invoke-Pac {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string[]]$PacArgs)

  & pac @PacArgs
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    # Mask any sensitive flags/values in the display string
    $displayArgs = @()
    for ($i = 0; $i -lt $PacArgs.Count; $i++) {
      $a = $PacArgs[$i]
      if ($a -ieq '--clientSecret' -or $a -ieq '--applicationId' -or $a -ieq '--tenant') {
        $displayArgs += $a
        if ($i + 1 -lt $PacArgs.Count) { $displayArgs += '***' ; $i++ }
      } else {
        $displayArgs += $a
      }
    }
    $cmd = 'pac ' + ($displayArgs -join ' ')
    throw ("❌ {0} failed (exit code {1})." -f $cmd, $code)
  }
}

# ── Load credentials (CredMan → Env vars → Param → Prompt for TenantId) ───────
Write-Info "`n🔐 Retrieving credentials securely..."

# Main credential: TargetName holds AppId (User) + ClientSecret (Secret)
$credMain = Get-CredentialManagerSecret -Target $TargetName

# Optional tenant credential: TargetName-Tenant holds TenantId in Secret
$credTenant = Get-CredentialManagerSecret -Target ($TargetName + '-Tenant')

# Fallback to environment variables if not in CredMan
if (-not $credMain -and $env:PP_APP_ID -and $env:PP_CLIENT_SECRET) {
  $credMain = @{ User = $env:PP_APP_ID; Secret = $env:PP_CLIENT_SECRET; Type='EnvVars' }
  Write-Warn "🔍 Using environment variables for AppId/Secret (PP_APP_ID / PP_CLIENT_SECRET)."
}

# TenantId priority: explicit param → CredMan → env var → prompt
if ([string]::IsNullOrWhiteSpace($TenantId)) {
  if ($credTenant -and -not [string]::IsNullOrWhiteSpace($credTenant.Secret)) {
    $TenantId = $credTenant.Secret
  } elseif ($env:PP_TENANT_ID) {
    $TenantId = $env:PP_TENANT_ID
    Write-Warn "🔍 Using environment variable for TenantId (PP_TENANT_ID)."
  }
}

# Validate presence
if (-not $credMain -or [string]::IsNullOrWhiteSpace($credMain.User) -or [string]::IsNullOrWhiteSpace($credMain.Secret)) {
  throw "No credentials found for '$TargetName'. Add via: cmdkey /add:$TargetName /user:<AppId> /pass:""<ClientSecret>"" OR set env vars PP_APP_ID & PP_CLIENT_SECRET."
}
if ([string]::IsNullOrWhiteSpace($TenantId)) {
  Write-Warn "🔍 TenantId not found in Credential Manager or env vars."
  $TenantId = Read-Host -Prompt 'Enter Tenant Id'
}

$AppId        = $credMain.User
$ClientSecret = $credMain.Secret

Write-Info "🧰 Using:`n  Tenant Id           : (hidden)`n  Application Id      : (hidden)`n  Environment URL     : $DevUrl`n  Solution unique name: $SolutionName`n  Cred Source         : $($credMain.Type)"

# ── Ensure PAC and authenticate ───────────────────────────────────────────────
Test-PacInstalled

Write-Info "`n🔐 Authenticating (service principal)..."
Invoke-Pac -PacArgs @('auth','clear')
Invoke-Pac -PacArgs @('auth','create','--tenant', $TenantId, '--applicationId', $AppId, '--clientSecret', $ClientSecret, '--url', $DevUrl)

Write-Info "🌐 Selecting active environment..."
Invoke-Pac -PacArgs @('org','select','--environment', $DevUrl)

Write-Info "🔎 Verifying connection (pac org who)..."
Invoke-Pac -PacArgs @('org','who')

# ── Export unmanaged solution ─────────────────────────────────────────────────
$Temp = Join-Path -Path (Get-Location) -ChildPath '_temp'
if (-not (Test-Path $Temp)) { New-Item -ItemType Directory -Path $Temp | Out-Null }

Write-Info "`n📦 Exporting solution '$SolutionName' (unmanaged)..."
Invoke-Pac -PacArgs @('solution','export','--environment', $DevUrl, '--name', $SolutionName, '--path', $Temp, '--managed', 'false')

# Preferred ZIP name; else newest ZIP in temp
$Zip = Join-Path $Temp "$SolutionName.zip"
if (-not (Test-Path $Zip)) {
  $latest = Get-ChildItem -Path $Temp -Filter *.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { throw "❌ No ZIPs found in $Temp after export." }
  $Zip = $latest.FullName
  Write-Warn "ℹ️ Using detected export: $Zip"
}

# ── Unpack into repo folder ───────────────────────────────────────────────────
$SolutionFolder = Join-Path -Path (Get-Location) -ChildPath ("solutions\" + $SolutionName)
if (-not (Test-Path $SolutionFolder)) { New-Item -ItemType Directory -Path $SolutionFolder | Out-Null }

Write-Info "🗂  Unpacking to $SolutionFolder ..."
Invoke-Pac -PacArgs @('solution','unpack','--zipfile', $Zip, '--folder', $SolutionFolder, '--packagetype', 'Unmanaged')

Write-OK "`n✅ Done. Folder ready for source control: $SolutionFolder"

Write-Host @"
Next steps:
  git add $SolutionFolder
  git commit -m "Unpacked $SolutionName from Dev"
  git push
"@

# ── Cleanup sensitive variables ───────────────────────────────────────────────
$ClientSecret = $null
$AppId = $null
$TenantId = $null
[GC]::Collect() | Out-Null