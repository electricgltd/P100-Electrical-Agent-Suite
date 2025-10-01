# Script: Clone GitHub Repo and Open Solution
# Author: Gareth Youens
# Purpose: Automate cloning and opening the P100 Electrical Agent Suite solution

# Variables
$githubUser = "electricgltd"
$repoName = "P100-Electrical-Agent-Suite"
$projectNumber = "2"
$localPath = "C:\Projects\P100-Electrical-Agent-Suite"

# Clone the repository if it doesn't exist
if (-Not (Test-Path $localPath)) {
    Write-Host "Cloning repository..."
    git clone https://github.com/$githubUser/$repoName.git $localPath
} else {
    Write-Host "Repository already exists. Pulling latest changes..."
    Set-Location $localPath
    git pull
}

# Navigate to solution folder
Set-Location "$localPath\Solutions\P100-Electrical-Agent-Suite"

# Open solution in Visual Studio
