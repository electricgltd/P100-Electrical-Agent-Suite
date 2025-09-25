param(
    [string]$Branch = "",
    [string]$Message = "chore: add devcontainer files",
    [string]$Title = "",
    [switch]$Draft
)

function Show-Usage { 
@"Usage: .\create_pr.ps1 [-Branch <name>] [-Message <commit message>] [-Title <PR title>] [-Draft]

Helper to create a branch, commit changes (if any), push, and open a draft PR using gh."@
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh (GitHub CLI) is required. Please install and authenticate gh before running this script."
    exit 2
}

if (-not $Branch -or $Branch -eq "") {
    $Branch = "pr/devcontainer-$(Get-Date -Format yyyyMMdd-HHmmss)"
}

if (-not $Title -or $Title -eq "") {
    $Title = $Message
}

$changes = git status --porcelain
if ($changes -ne "") {
    Write-Host "There are local changes. These will be committed with message: $Message"
    git add -A
    git commit -m $Message
} else {
    Write-Host "No local changes to commit. Creating branch from current HEAD."
}

git checkout -b $Branch
git push -u origin $Branch

$prArgs = @("pr", "create", "--title", $Title, "--body-file", ".pr_body.md")
if ($Draft) { $prArgs += "--draft" }

Write-Host "Running: gh $($prArgs -join ' ')"
gh @prArgs
