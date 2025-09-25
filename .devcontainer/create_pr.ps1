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

function Switch-Or-Checkout {
    param([string]$BranchName)

    if ([string]::IsNullOrWhiteSpace($BranchName)) {
        Write-Error "Branch name is empty. Provide a non-empty branch name."
        exit 1
    }

    # Detect whether branch exists locally
    git rev-parse --verify "refs/heads/$BranchName" > $null 2>&1
    $branchExists = ($LASTEXITCODE -eq 0)

    if ($branchExists) {
        # Try git switch, fallback to checkout
        git switch $BranchName 2>$null
        if ($LASTEXITCODE -ne 0) { git checkout $BranchName }
    } else {
        # Try creating and switching with git switch -c, fallback to checkout -b
        git switch -c $BranchName 2>$null
        if ($LASTEXITCODE -ne 0) { git checkout -b $BranchName }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create or switch to branch '$BranchName'."
        exit 1
    }
}

# Get porcelain output and test reliably for content
$changes = git status --porcelain
$hasChanges = -not [string]::IsNullOrWhiteSpace(($changes -join "`n"))

if ($hasChanges) {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Error "Commit message is empty. Provide a non-empty -Message."
        exit 1
    }
    Write-Host "There are local changes. These will be committed with message: $Message"
    git add -A
    git commit -m $Message
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git commit failed."
        exit 1
    }
    # After committing, create/switch to the branch (if provided)
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        Switch-Or-Checkout -Branch $Branch
    }
} else {
    Write-Host "No local changes to commit. Creating/switching to branch '$Branch' from current HEAD."
    Switch-Or-Checkout -Branch $Branch
}

# Push upstream (set upstream if not already set)
git push -u origin $(git rev-parse --abbrev-ref HEAD)

$prArgs = @("pr", "create", "--title", $Title, "--body-file", ".pr_body.md")
if ($Draft) { $prArgs += "--draft" }

Write-Host "Running: gh $($prArgs -join ' ')"
gh @prArgs
