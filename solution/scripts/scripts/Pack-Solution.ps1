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
