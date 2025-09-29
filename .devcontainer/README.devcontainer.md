# Devcontainer notes — P100 Electrical Agent Suite

This file documents the devcontainer purpose, first-run steps, and quick troubleshooting. It is intended to be opened after the container is created.

Why use the devcontainer
- Provides a reproducible environment for working with Power Platform/Dataverse ALM (pac CLI), Python-based MCP dev server, and agent grounding files.
- Installs recommended VS Code extensions and helper scripts so contributors can start quickly.

First-run steps (Codespaces / Remote - Containers)
1. Open the repository in a container (Reopen in Container / Codespace). The `postCreateCommand` will run automatically.
2. Verify `pac` (Power Platform CLI) is available:
   ```bash
   pac --version
   ```
   If not found, ensure `~/.dotnet/tools` is on PATH (the postCreate script writes this into `~/.profile`). Reopen the terminal or run `source ~/.profile`.
3. Verify PowerShell is available (optional):
   ```bash
   pwsh --version
   ```
4. Verify Python 3.11 is available (used for `mcp` and other scripts):
   ```bash
   python3.11 --version
   ```

Running the MCP dev server locally (for proposals and tests)
1. Create and activate a venv (PowerShell example):
   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r mcp/requirements.txt
   setx MCP_DEV_TOKEN "your-secret-token"
   uvicorn mcp.app:app --host 0.0.0.0 --port 8080 --reload
   ```
2. Quick insecure test (dev only):
   - Set `MCP_DEV_ALLOW_INSECURE=true` and use `Authorization: Bearer dev-token` in requests.

Using the PR helper
- From the container shell run `.devcontainer/create_pr.sh --help` to see options. `gh` must be installed and authenticated.

Troubleshooting
- pac not found after install: ensure `~/.dotnet/tools` is on PATH. Run `echo $PATH` and `ls -la ~/.dotnet/tools`.
- pac install errors: check `dotnet --info` and network/proxy restrictions. PostCreate uses `dotnet tool install --global`.
- pwsh/python apt installs may fail on non-debian images; the postCreate script is best-effort. Use a custom devcontainer image if you need guaranteed tool availability.

Making a custom image (optional)
- See `.devcontainer/Dockerfile` (if present) as an example of pre-baking `pac` and Python. Building a custom image is recommended for large teams to reduce setup time.

If you want, I can build a small PR that adds `.devcontainer/Dockerfile` (example) and updates `devcontainer.json` to reference it. This will pre-install pac and Python for faster start-up.
