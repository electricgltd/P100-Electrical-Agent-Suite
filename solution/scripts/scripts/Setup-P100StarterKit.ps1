<# ========================================================================
 Setup-P100StarterKit.ps1  (public-safe)

 Creates a repository scaffold for the P100 Electrical Agent Suite, copies
 your existing OneDrive content into a clean structure, adds:
  - .gitignore (safe for public)
  - README.md
  - env/dev-setup.yaml (WinGet config, no secrets)
  - scripts/Export-Unpack.ps1 and Pack-Solution.ps1 (no secrets)
  - .github/workflows/power-platform.yml (uses GitHub Secrets only)

 It can also create the GitHub repo and push the first commit via GitHub CLI.

 Prereqs:
  - Git installed (https://git-scm.com/)
  - (Recommended) PowerShell 7 (winget install Microsoft.PowerShell)
  - GitHub CLI installed & logged in: winget install GitHub.cli ; gh auth login

 Usage examples:
  - Scaffold + copy + create remote (private by default):
      pwsh -File C:\Dev\Setup-P100StarterKit.ps1 -CreateRemoteWithGH
  - Same but immediately public:
      pwsh -File C:\Dev\Setup-P100StarterKit.ps1 -CreateRemoteWithGH -Visibility public
  - Scaffold without copying from OneDrive:
      pwsh -File C:\Dev\Setup-P100StarterKit.ps1 -SkipCopy

 ======================================================================== #>

[CmdletBinding()]
param(
  [string]$OneDrivePath = "C:\Users\GarethYouens\OneDrive - Electric G Ltd\IT\Copilot Agents\25Q4 P100 Copilot Electrical Agent Suite",
  [string]$LocalRepoPath = "C:\Dev\P100-Electrical-Agent-Suite",
  [string]$RepoName      = "P100-Electrical-Agent-Suite",
  [switch]$CreateRemoteWithGH,
  [ValidateSet("public","private")] [string]$Visibility = "private",
  [switch]$SkipCopy
)

# -------------------- helpers --------------------
function New-Folder($path) {
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}
function Write-TextFile($path, [string]$content) {
  $dir = Split-Path $path
  New-Folder $dir
  Set-Content -Path $path -Value $content -Encoding UTF8
  Write-Host "Created: $path"
}
function Test-Command($name) {
  try { Get-Command $name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

# -------------------- sanity checks --------------------
if (-not (Test-Path $OneDrivePath) -and -not $SkipCopy) {
  Write-Warning "OneDrive path not found: $OneDrivePath"
  Write-Warning "Use -SkipCopy to scaffold without copying or set -OneDrivePath correctly."
  throw "Aborting."
}
if (-not (Test-Command git)) { throw "Git not found in PATH. Install Git and try again." }
if ($CreateRemoteWithGH -and -not (Test-Command gh)) { throw "GitHub CLI (gh) not found. Install with: winget install GitHub.cli" }

# -------------------- folders --------------------
New-Folder $LocalRepoPath
$sub = @(
  "agents\EA",
  "agents\PA",
  "agents\DCA",
  "docs\orchestration",
  "docs\templates",
  "flows",
  "solutions",
  "scripts",
  "env",
  ".github\workflows"
)
$sub | ForEach-Object { New-Folder (Join-Path $LocalRepoPath $_) }

# -------------------- copy content from OneDrive --------------------
if (-not $SkipCopy) {
  Write-Host "Copying content from OneDrive..."
  $map = @(
    @{ src = "Electrical_Agent";          dst = "agents\EA" },
    @{ src = "Planning_Agent";            dst = "agents\PA" },
    @{ src = "Design_and_Costing_Agent";  dst = "agents\DCA" },
    @{ src = "Orchestration_Flow";        dst = "docs\orchestration" },
    @{ src = "Power_Automate_Flows";      dst = "flows" },
    @{ src = "Templates";                 dst = "docs\templates" }
  )
  foreach ($m in $map) {
    $s = Join-Path $OneDrivePath $m.src
    $d = Join-Path $LocalRepoPath $m.dst
    if (Test-Path $s) {
      Copy-Item "$s\*" $d -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  Copied: $m.src  ->  $m.dst"
    } else {
      Write-Warning "  Skipped (not found): $s"
    }
  }
} else {
  Write-Host "SkipCopy set. Not copying OneDrive content."
}

# -------------------- .gitignore (public-safe) --------------------
$gitignore = @'
# --- OS / Office temp ---
Thumbs.db
desktop.ini
~$*

# --- IDE cache ---
.vscode/
*.user

# --- Build & exports ---
/_exports/
/_artifacts/
/bin/
/obj/
*.log
# --- Node/Yarn ---
node_modules/
package-lock.json
yarn.lock

# --- Power Platform canvas binaries (keep source instead) ---
*.msapp

# --- Secrets & env files (DO NOT COMMIT) ---
.env
.env.*
*.secret
*.secrets
*.pfx
*.snk
*.key
secrets.json
appsettings.Development.json
PrivateSettings.json

# --- Misc shortcuts ---
*.lnk
*.url

# --- Archives & large binary bundles ---
*.zip
*.7z
*.tar
*.gz
'@
Write-TextFile (Join-Path $LocalRepoPath ".gitignore") $gitignore

# -------------------- README (no PII) --------------------
$readme = @'
# P100 Electrical Agent Suite

Parent/child Copilot Studio agents for an NICEIC electrical contractor:
- **EA** (Electrical Assistant) – orchestrates workflows
- **PA** (Planning Assistant)
- **DCA** (Design & Costing Assistant)

## Structure
- `/agents` – grounding files and agent docs (EA/PA/DCA)
- `/docs` – orchestration notes, templates
- `/flows` – Power Automate flow definitions/docs
- `/solutions` – unpacked Dataverse solution source
- `/scripts` – ALM automation (pack/unpack)
- `/env` – WinGet configuration and local-only samples

> **Public-safety**: no secrets are stored in this repo. Use **GitHub Secrets** and local `.env` files (excluded by `.gitignore`).
'@
Write-TextFile (Join-Path $LocalRepoPath "README.md") $readme

# -------------------- WinGet configuration (no secrets) --------------------
$winget = @'
# Windows Package Manager Configuration (public-safe)
# Docs: https://learn.microsoft.com/windows/package-manager/configuration
manifestVersion: 1.6.0
components:
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: Git.Git
    intent: install
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: Microsoft.PowerShell
    intent: install
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: Microsoft.PowerPlatformCLI
    intent: install
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: Microsoft.VisualStudioCode
    intent: install
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: OpenJS.NodeJS.LTS
    intent: install
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: GitHub.GitHubDesktop
    intent: install
  # Optional: secret scanning
  - component: Microsoft.WinGet.DSC/WinGetPackage
    id: zricethezav.gitleaks
    intent: install
'@
Write-TextFile (Join-Path $LocalRepoPath "env\dev-setup.yaml") $winget

# -------------------- sample .env (documentation only) --------------------
$envSample = @'
# Sample environment variables (DO NOT COMMIT a real .env file)
# Copy to .env locally and fill values if your scripts read from it.

PP_TENANT_ID=
PP_APP_ID=
PP_CLIENT_SECRET=
PP_DEV_URL=https://<your-org>.crm.dynamics.com
PP_TEST_URL=https://<your-test-org>.crm.dynamics.com
'@
Write-TextFile (Join-Path $LocalRepoPath "env\.env.sample") $envSample

# -------------------- ALM scripts (single-quoted here-strings) --------------------
$exportUnpack = @'
<#
Export-Unpack.ps1
Exports an UNMANAGED solution from DEV and unpacks to source.
Prereq: pac CLI authenticated (Device code or SP).
#>
param(
  [Parameter(Mandatory=$true)][string]$SolutionName,
  [string]$ExportFolder = "_exports",
  [string]$OutputFolder = "solutions",
  [switch]$ProcessCanvasApps
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command pac -ErrorAction SilentlyContinue)) { throw 'Power Platform CLI (pac) not found.' }

New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
$zip = Join-Path $ExportFolder ("{0}_Unmanaged.zip" -f $SolutionName)

Write-Host "Exporting solution: $SolutionName"
pac solution export --name $SolutionName --path $zip --managed false --overwrite true

$target = Join-Path $OutputFolder $SolutionName
Write-Host "Unpacking to: $target"
$flag = $ProcessCanvasApps.IsPresent ? "--processCanvasApps true" : ""
pac solution unpack --zipfile $zip --folder $target --allowDelete true $flag
Write-Host "Done."
'@
Write-TextFile (Join-Path $LocalRepoPath "scripts\Export-Unpack.ps1") $exportUnpack

$packSolution = @'
<#
Pack-Solution.ps1
Packs the unpacked solution folder back into a ZIP artifact (UNMANAGED).
#>
param(
  [Parameter(Mandatory=$true)][string]$SolutionFolder,  # e.g., solutions\P100_ElectricalAgentSuite
  [string]$ArtifactFolder = "_artifacts"
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command pac -ErrorAction SilentlyContinue)) { throw 'Power Platform CLI (pac) not found.' }

New-Item -ItemType Directory -Path $ArtifactFolder -Force | Out-Null
$zip = Join-Path $ArtifactFolder ("{0}_Unmanaged.zip" -f (Split-Path $SolutionFolder -Leaf))

Write-Host "Packing: $SolutionFolder"
pac solution pack --folder $SolutionFolder --zipfile $zip --managed false
Write-Host "Output: $zip"
'@
Write-TextFile (Join-Path $LocalRepoPath "scripts\Pack-Solution.ps1") $packSolution

# -------------------- GitHub Actions workflow (keeps ${{ secrets.* }} literal) --------------------
$workflow = @'
name: Power Platform ALM

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:
  pack:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Power Platform CLI
        run: winget install Microsoft.PowerPlatformCLI --silent
      - name: Pack solution (unmanaged)
        run: |
          pac auth create --tenant ${{ secrets.PP_TENANT_ID }} --applicationId ${{ secrets.PP_APP_ID }} --clientSecret ${{ secrets.PP_CLIENT_SECRET }} --url ${{ secrets.PP_DEV_URL }}
          pac solution pack --zipfile _artifacts/P100_ElectricalAgentSuite_Unmanaged.zip --folder solutions/P100_ElectricalAgentSuite --managed false
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: solution-unmanaged
          path: _artifacts/P100_ElectricalAgentSuite_Unmanaged.zip

  import_to_test:
    needs: pack
    if: github.ref == 'refs/heads/main'
    runs-on: windows-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: solution-unmanaged
          path: _artifacts
      - name: Install Power Platform CLI
        run: winget install Microsoft.PowerPlatformCLI --silent
      - name: Import to TEST
        run: |
          pac auth create --tenant ${{ secrets.PP_TENANT_ID }} --applicationId ${{ secrets.PP_APP_ID }} --clientSecret ${{ secrets.PP_CLIENT_SECRET }} --url ${{ secrets.PP_TEST_URL }}
          pac solution import --path _artifacts/P100_ElectricalAgentSuite_Unmanaged.zip --publish-changes true --force-overwrite true
'@
Write-TextFile (Join-Path $LocalRepoPath ".github\workflows\power-platform.yml") $workflow

# -------------------- preflight checks (public safety) --------------------
Write-Host "`nRunning preflight checks..."
$large = Get-ChildItem -Path $LocalRepoPath -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Length -gt 50MB -and $_.FullName -notmatch '\\(_exports|_artifacts)\\' }
if ($large) {
  Write-Warning "Files > 50MB found (consider remove or LFS before pushing):"
  $large | ForEach-Object { "{0}  ({1:N1} MB)" -f $_.FullName, ($_.Length/1MB) } | Write-Host
}

$possibleSecrets = Get-ChildItem -Path $LocalRepoPath -Recurse -File -Include *.json,*.ps1,*.yml,*.yaml,*.txt -ErrorAction SilentlyContinue |
  Select-String -Pattern '(?i)(client[_-]?secret|password|apikey|token)\s*[:=]\s*["''][A-Za-z0-9\._\-]{10,}'
if ($possibleSecrets) {
  Write-Warning "Potential secret-like strings detected (manual review advised):"
  $possibleSecrets | ForEach-Object { Write-Host ("  - {0}:{1}" -f $_.Path, $_.LineNumber) }
  Write-Host "Tip: run 'gitleaks detect -s $LocalRepoPath' for a stronger scan (installed via WinGet config)."
}

# -------------------- initialise git & first commit --------------------
Set-Location $LocalRepoPath
git init
git config core.longpaths true
git add .
git commit -m "Initial import: scaffold, env config, ALM scripts, workflow (no secrets)"

# -------------------- remote creation / push --------------------
if ($CreateRemoteWithGH) {
  # If repo already exists under this name, 'gh repo view' returns 0; handle gracefully.
  $exists = $false
  try { gh repo view $RepoName | Out-Null; $exists = $true } catch { $exists = $false }

  if ($exists) {
    Write-Warning "Repo '$RepoName' already exists on GitHub. Linking to existing remote..."
    $owner = (gh api user --jq .login)
    $remoteUrl = "https://github.com/$owner/$RepoName.git"
    git remote add origin $remoteUrl 2>$null
    git branch -M main
    git push -u origin main
  } else {
    Write-Host "Creating $Visibility repo '$RepoName' via GitHub CLI..."
    gh repo create $RepoName --$Visibility --source "$LocalRepoPath" --remote origin --push
  }
} else {
  $remote = Read-Host "Enter your GitHub repo HTTPS URL (or leave blank to skip remote setup)"
  if ($remote) {
    git remote add origin $remote
    git branch -M main
    git push -u origin main
  } else {
    Write-Host "Skipping remote setup. You can add later with: git remote add origin <url>"
  }
}

Write-Host "`n✅ Starter kit complete."
Write-Host "Next: Add GitHub Secrets: PP_TENANT_ID, PP_APP_ID, PP_CLIENT_SECRET, PP_DEV_URL, PP_TEST_URL"
