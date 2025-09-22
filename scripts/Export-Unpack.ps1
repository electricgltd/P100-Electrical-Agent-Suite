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
