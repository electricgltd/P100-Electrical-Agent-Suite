#!/usr/bin/env pwsh
Set-StrictMode -Version Latest

Write-Host "Running PowerShell postCreate: installing pac, pwsh checks, and optional Python 3.11"

function Install-PacIfMissing {
    if (Get-Command pac -ErrorAction SilentlyContinue) {
        Write-Host "pac already installed at $(Get-Command pac)."
        return
    }
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Write-Host "Installing pac via dotnet tool (user-local)"
        try {
            dotnet tool install --global Microsoft.PowerApps.CLI.Tool -ErrorAction Stop
        } catch {
            Write-Warning "dotnet tool install failed; attempting update"
            dotnet tool update --global Microsoft.PowerApps.CLI.Tool -ErrorAction SilentlyContinue
        }
        $env:PATH = "$env:USERPROFILE/.dotnet/tools;$env:PATH"
    } else {
        Write-Warning "dotnet not found; cannot install pac automatically"
    }
}

function Install-PwshIfMissing {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Host "pwsh present at $(Get-Command pwsh)."
        return
    }
    if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        Write-Host "Detected apt-get. Attempting to install pwsh via apt"
        try {
            $tmp = "/tmp/packages-microsoft-prod.deb"
            Invoke-WebRequest -Uri "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb" -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            sudo dpkg -i $tmp
            sudo apt-get update -y
            sudo apt-get install -y powershell
        } catch {
            Write-Warning "pwsh install failed: $_"
        }
    } else {
        Write-Host "No apt-get found; skipping pwsh install."
    }
}

function Install-Python311IfMissing {
    if (Get-Command python3.11 -ErrorAction SilentlyContinue) {
        Write-Host "python3.11 already present: $(python3.11 --version)"
        return
    }
    if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        Write-Host "Detected apt-get. Installing python3.11..."
        try {
            sudo apt-get update -y
            sudo apt-get install -y software-properties-common || true
            sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils || true
            # ensure pip
            if (-not (python3.11 -m pip --version -ErrorAction SilentlyContinue)) {
                Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile "/tmp/get-pip.py" -UseBasicParsing -ErrorAction Stop
                sudo python3.11 /tmp/get-pip.py
            }
        } catch {
            Write-Warning "python3.11 install failed: $_"
        }
    } else {
        Write-Host "No apt-get found; skipping python3.11 install."
    }
}

Install-PacIfMissing
Install-PwshIfMissing
Install-Python311IfMissing

Write-Host "Post-create PowerShell tasks complete. Next steps: activate venv, install requirements, and use create_pr.ps1 for PRs."
