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
    # Ensure ~/.dotnet/tools is on PATH for the remainder of the script and persist it for future shells
    DOTNET_TOOLS="$HOME/.dotnet/tools"
    export PATH="$DOTNET_TOOLS:$PATH"
    # Persist the dotnet tools path for interactive shells (idempotent)
    SHELL_PROFILE="$HOME/.profile"
    if ! grep -qxF "# add dotnet tools to PATH" "$SHELL_PROFILE" 2>/dev/null; then
      echo "# add dotnet tools to PATH" >> "$SHELL_PROFILE"
      echo "export PATH=\"$DOTNET_TOOLS:\$PATH\"" >> "$SHELL_PROFILE"
    fi
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

# Install PowerShell (pwsh) if not present - idempotent and best-effort on Debian/Ubuntu-based images
if command -v pwsh >/dev/null 2>&1; then
  echo "pwsh already present at $(command -v pwsh)."
else
  echo "pwsh not found. Attempting to install PowerShell (idempotent)."
  # Only attempt apt-based install if apt-get exists
  if command -v apt-get >/dev/null 2>&1; then
    echo "Detected apt-get. Installing PowerShell via Microsoft package feed..."
    set +e
    TMP_DEB="/tmp/packages-microsoft-prod.deb"
    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O "$TMP_DEB" || true
    if [ -f "$TMP_DEB" ]; then
      sudo dpkg -i "$TMP_DEB" || true
      sudo apt-get update -y || true
      sudo apt-get install -y powershell || true
    else
      echo "Could not download Microsoft package feed deb; skipping pwsh install."
    fi
    set -e
  else
    echo "No apt-get detected; skipping automatic pwsh install. You can install pwsh manually if needed."
  fi
fi

# Install Python 3.11 if not present (idempotent) on Debian/Ubuntu-based images
if command -v python3.11 >/dev/null 2>&1; then
  echo "python3.11 already present: $(python3.11 --version)"
else
  echo "python3.11 not found. Attempting apt-based install of Python 3.11 (idempotent)."
  if command -v apt-get >/dev/null 2>&1; then
    echo "Detected apt-get. Installing python3.11 and venv support..."
    set +e
    sudo apt-get update -y || true
    sudo apt-get install -y software-properties-common || true
    # On some images python3.11 is available directly; try install
    sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils || true
    # Ensure pip for python3.11 exists
    if ! command -v python3.11 >/dev/null 2>&1; then
      echo "python3.11 still not found after apt install; skipping pip setup."
    else
      if ! python3.11 -m pip --version >/dev/null 2>&1; then
        echo "Installing pip for python3.11 via get-pip.py"
        curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || true
        sudo python3.11 /tmp/get-pip.py || true
      fi
    fi
    set -e
  else
    echo "No apt-get detected; skipping automatic python3.11 install. You can install Python manually if needed."
  fi
fi


echo "Post-create tasks complete. Next steps:"
echo " - Open a terminal in the Codespace (or container) and run:"
echo "     git checkout -b my-codespace-branch"
echo "     ./.devcontainer/create_pr.sh --help   # to see the helper options for creating a draft PR"
echo " - If you need Python dependencies for the 'mcp' service, run:"
echo "     python -m pip install -r github_app/requirements.txt"

exit 0
