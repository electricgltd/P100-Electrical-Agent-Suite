MCP (Minimal Control Plane) dev server

This small FastAPI app is a development helper for proposing changes (like labels) and reading repository files.

Run locally (recommended):

1. Create a virtualenv and install requirements:

```pwsh
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Start the server (dev mode):

```pwsh
setx MCP_DEV_TOKEN "your-secret-token"
uvicorn mcp.app:app --host 0.0.0.0 --port 8080 --reload
```

Notes
- This server is intentionally minimal. For production use replace the token auth with a proper GitHub App or OAuth flow.
- Use `MCP_DEV_ALLOW_INSECURE=true` together with the default `dev-token` for local testing when you don't want to set a token.
