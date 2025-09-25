#!/usr/bin/env bash
set -euo pipefail

echo "Running devcontainer postCreate: installing Power Platform CLI (pac) safely"

# Use a local temp folder to download/install without touching global state unnecessarily
TMP_DIR="/tmp/p100-devcontainer-setup"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

if command -v pac >/dev/null 2>&1; then
  echo "pac already installed at $(command -v pac). Skipping pac install."
else
  echo "Installing Pac CLI via dotnet tool (user-local). This requires dotnet to be available in the image."
  # install to the user-level tool path
  if dotnet --version >/dev/null 2>&1; then
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool || {
      echo "dotnet tool install failed; attempting to update and retry"
      dotnet tool update --global Microsoft.PowerApps.CLI.Tool || true
    }
    # Ensure ~/.dotnet/tools is on PATH for the remainder of the script and instruct the user
    export PATH="$HOME/.dotnet/tools:$PATH"
  else
    echo "dotnet not found in the container image. Please install dotnet or use an image with dotnet preinstalled."
    exit 1
  fi
fi

echo "Verifying pac installation..."
if pac --version >/dev/null 2>&1; then
  echo "pac is installed: $(pac --version)"
else
  echo "pac not found after installation attempt. Check the logs above."
fi

echo "Post-create tasks complete. Next steps:"
echo " - Open a terminal in the Codespace (or container) and run:"
echo "     git checkout -b my-codespace-branch"
echo "     ./.devcontainer/create_pr.sh --help   # to see the helper options for creating a draft PR"
echo " - If you need Python dependencies for the 'mcp' service, run:"
echo "     python -m pip install -r github_app/requirements.txt"

exit 0
