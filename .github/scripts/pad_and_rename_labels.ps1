Param(
    [switch]$Apply
)

$repoOwner = 'electricgltd'
$repoName = 'P100-Electrical-Agent-Suite'
$csvPath = 'docs/GitHub/Colour_Labels_GitHub.csv'

if (-not (Test-Path $csvPath)) {
    Write-Error "CSV not found: $csvPath"
    exit 2
}

# Read CSV
$rows = Import-Csv $csvPath

# Parse numeric prefixes and find max width
$items = @()
$maxNum = 0
foreach ($r in $rows) {
    if ($r.Name -match '^\s*(\d+)\s+(.*)$') {
        $num = [int]$matches[1]
        $rest = $matches[2]
    }
    else {
        # No numeric prefix - keep as-is, treat num as null
        $num = $null
        $rest = $r.Name
    }
    if ($null -ne $num -and $num -gt $maxNum) { $maxNum = $num }
    $items += [pscustomobject]@{ OriginalName = $r.Name; Number = $num; Rest = $rest; Colour = $r.Colour }
}

if ($maxNum -lt 10) { $width = 2 } else { $width = $maxNum.ToString().Length }

Write-Output "Padding numeric prefixes to width $width"

# Build mappings
$mappings = @()
foreach ($it in $items) {
    if ($null -ne $it.Number) {
        $padded = $it.Number.ToString().PadLeft($width,'0')
        $newName = "$padded $($it.Rest)"
    }
    else {
        $newName = $it.OriginalName
    }
    $mappings += [pscustomobject]@{ Old = $it.OriginalName; New = $newName; Colour = $it.Colour }
}

Write-Output "Applying renames to GitHub labels (Apply=$Apply)"

foreach ($map in $mappings) {
    $old = $map.Old
    $new = $map.New
    $color = $map.Colour
    $desc = 'Imported from Colour_Labels_GitHub.csv'

    if ($old -eq $new) {
        # No rename needed, but ensure color/description
        if ($Apply) {
            Write-Output "Updating: $new (color set to $color)"
            $enc = [uri]::EscapeDataString($new)
            gh api repos/$repoOwner/$repoName/labels/$enc -X PATCH -f name="$new" -f color="$color" -f description="$desc" | Out-Null
        }
        else { Write-Output "Would update: $new ($color)" }
        continue
    }

    $oldEnc = [uri]::EscapeDataString($old)
    $newEnc = [uri]::EscapeDataString($new)

    # Check existence
    $oldExists = $true
    $newExists = $true
    try { gh api repos/$repoOwner/$repoName/labels/$oldEnc -q .name > $null 2>&1 } catch { $oldExists = $false }
    try { gh api repos/$repoOwner/$repoName/labels/$newEnc -q .name > $null 2>&1 } catch { $newExists = $false }

    if (-not $oldExists -and -not $newExists) {
        # Neither exist - create new if Apply
        if ($Apply) {
            Write-Output "Creating new label: $new ($color)"
            gh label create --color $color --description $desc -- "$new" | Out-Null
        }
        else { Write-Output "Would create: $new ($color)" }
        continue
    }

    if (-not $oldExists -and $newExists) {
        # Old missing, new exists - just update color/desc
        if ($Apply) {
            Write-Output "Updating existing: $new ($color)"
            gh api repos/$repoOwner/$repoName/labels/$newEnc -X PATCH -f name="$new" -f color="$color" -f description="$desc" | Out-Null
        }
        else { Write-Output "Would update existing: $new ($color)" }
        continue
    }

    if ($oldExists -and -not $newExists) {
        # Rename old -> new
        if ($Apply) {
            Write-Output "Renaming: '$old' -> '$new'"
            gh api repos/$repoOwner/$repoName/labels/$oldEnc -X PATCH -f name="$new" -f color="$color" -f description="$desc" | Out-Null
        }
        else { Write-Output "Would rename: '$old' -> '$new'" }
        continue
    }

    # both exist - avoid collision by temporary rename of new
    if ($oldExists -and $newExists) {
    $temp = "$new-temp-$(Get-Date -Format yyyyMMddHHmmss)"
        if ($Apply) {
            Write-Output "Conflict: both exist. Renaming existing '$new' -> '$temp'"
            gh api repos/$repoOwner/$repoName/labels/$newEnc -X PATCH -f name="$temp" -f color="$color" -f description="$desc" | Out-Null
            Write-Output "Renaming: '$old' -> '$new'"
            gh api repos/$repoOwner/$repoName/labels/$oldEnc -X PATCH -f name="$new" -f color="$color" -f description="$desc" | Out-Null
            Write-Output "Renaming temp '$temp' -> '$old'"
            $tempOldEnc = [uri]::EscapeDataString($temp)
            gh api repos/$repoOwner/$repoName/labels/$tempOldEnc -X PATCH -f name="$old" -f color="$color" -f description="$desc" | Out-Null
        }
        else {
            Write-Output "Would resolve conflict: rename '$new' -> '$temp', '$old' -> '$new', '$temp' -> '$old'"
        }
    }
}

# If Apply, update CSV to use new names
if ($Apply) {
    Write-Output "Updating CSV: $csvPath"
    $outRows = @()
    foreach ($map in $mappings) {
        $outRows += [pscustomobject]@{ Name = $map.New; Colour = $map.Colour }
    }
    $outRows | Export-Csv -NoTypeInformation -Path $csvPath

    # Commit and push
    git add $csvPath
    git commit -m "chore(labels): pad numeric prefixes for label sorting" || Write-Output "No changes to commit"
    git push
    Write-Output "CSV updated and pushed."
}

Write-Output "Done."
