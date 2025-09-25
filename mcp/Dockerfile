FROM python:3.11-slim

# Create and use application directory
WORKDIR /app

# Install only requirements first to leverage layer caching
# The docker-compose build context is the repo root, so copy the file from /mcp/requirements.txt
COPY mcp/requirements.txt /app/requirements.txt

# Install OS-level build dependencies needed to compile wheels (PyYAML, etc.)
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		build-essential \
		gcc \
		libyaml-dev \
		ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Upgrade pip and wheel to improve build compatibility, then install requirements
RUN python -m pip install --upgrade pip setuptools wheel && \
	pip install --no-cache-dir -r /app/requirements.txt

# Copy only the application package to avoid copying the whole repository
COPY mcp /app/mcp

# Expose port used by uvicorn
EXPOSE 8080

# Run the app
CMD ["uvicorn", "mcp.app:app", "--host", "0.0.0.0", "--port", "8080"]
