Local GitHub Actions runner (act) — quick start

This file shows how to install and run workflows locally using `act` (nektos/act).
The commands below are PowerShell-friendly and focused on the `DoctorGPhD • Rules validation` workflow in this repo.

Prerequisites
- Docker Desktop running (WSL2 backend recommended on Windows).
- Enough disk/CPU to pull runner images.

Install act (three options)
- Scoop (recommended on Windows):
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  iwr -useb get.scoop.sh | iex
  scoop install act
  ```
- Chocolatey:
  ```powershell
  choco install act -y
  ```
- Manual: download the Windows release from https://github.com/nektos/act/releases and add binary to your PATH.

Verify installation
```powershell
act --version
docker version    # ensure Docker is running
```

Dry-run a workflow (show steps, do not execute)
```powershell
act -W .github/workflows/github_workflows_doctorgphd-checks.yml -j validate-doctorgphd --dryrun
# or short (some act versions):
act -W .github/workflows/github_workflows_doctorgphd-checks.yml -j validate-doctorgphd -n
```

Run the job locally (executes actions inside Docker)
```powershell
act -W .github/workflows/github_workflows_doctorgphd-checks.yml -j validate-doctorgphd
```

Helpful options
- Map runner labels to specific images (example):
  ```powershell
  act -W .github/workflows/github_workflows_doctorgphd-checks.yml -j validate-doctorgphd -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:full-22.04
  ```
- Provide secrets / environment variables via an env file:
  ```powershell
  # .env content: MY_SECRET=secretvalue
  act -W .github/workflows/github_workflows_doctorgphd-checks.yml -j validate-doctorgphd --env-file .env
  ```

Quick alternative (fast): run the validator directly
```powershell
python scripts/validate_doctorgphd.py "config/DoctorGPhD ruleset.yaml"
```
This is faster when you only need to validate a rules file and don't need to run the whole workflow.

Common gotchas
- Docker must be running before invoking `act`.
- act's default runner image can differ from GitHub's hosted runner; use `-P` to match images closely.
- Some composite or marketplace actions may behave differently locally; consider mocking external services.

If you want, I can add a small script to pre-pull images or a sample `.env` for local runs.
