FROM mcr.microsoft.com/devcontainers/dotnet:8.0

# Example Dockerfile that pre-installs pac (Power Platform CLI) and Python 3.11
# Use this to build a custom image if you want faster devcontainer startup.

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates apt-transport-https software-properties-common gnupg && \
    # Install PowerShell (optional)
    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb && \
    dpkg -i /tmp/packages-microsoft-prod.deb || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell python3.11 python3.11-venv python3.11-distutils python3-pip && \
    rm -rf /var/lib/apt/lists/* /tmp/packages-microsoft-prod.deb

# Install pac as a global dotnet tool into /root/.dotnet/tools
RUN dotnet tool install --global Microsoft.PowerApps.CLI.Tool || true

ENV PATH="/root/.dotnet/tools:${PATH}"

CMD ["sleep", "infinity"]
