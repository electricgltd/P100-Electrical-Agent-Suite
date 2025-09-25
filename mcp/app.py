from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.responses import PlainTextResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Request
from pathlib import Path
import os
import logging
import yaml
import time

APP_ROOT = Path(__file__).resolve().parent
REPO_ROOT = APP_ROOT.parent

app = FastAPI(title="MCP Dev API")

# Basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('mcp')

# CORS - dev only but harmless for local usage
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET","POST","OPTIONS"],
    allow_headers=["*"],
)

# Authentication helper
DEV_TOKEN = os.getenv('MCP_DEV_TOKEN')
ALLOW_INSECURE = os.getenv('MCP_DEV_ALLOW_INSECURE','false').lower() in ['1','true','yes']

def require_token(authorization: str = Header(None)):
    """Dependency that validates Authorization: Bearer <token> header.

    Behavior:
    - If MCP_DEV_TOKEN is set, it MUST match the provided token.
    - If MCP_DEV_TOKEN is NOT set, the server will only allow requests when
      MCP_DEV_ALLOW_INSECURE=true (dev/testing) and the token equals 'dev-token'.
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Missing bearer token')
    token = authorization.split(' ',1)[1]
    if DEV_TOKEN:
        if token != DEV_TOKEN:
            raise HTTPException(status_code=403, detail='Invalid token')
    else:
        if not ALLOW_INSECURE or token != 'dev-token':
            raise HTTPException(status_code=403, detail='Invalid or missing server token')
    return token


@app.get('/health')
def health():
    return JSONResponse({'status':'ok'})


def _resolve_repo_path(rel_path: str) -> Path:
    # Normalise and prevent path traversal
    rp = Path(rel_path)
    if rp.is_absolute():
        # make relative
        rp = rp.relative_to(rp.anchor)
    target = (REPO_ROOT / rp).resolve()
    if not str(target).startswith(str(REPO_ROOT)):
        raise HTTPException(status_code=400, detail='Invalid path')
    return target


@app.get('/file', response_class=PlainTextResponse)
def get_file(path: str, token: str = Depends(require_token)):
    target = _resolve_repo_path(path)
    if not target.exists() or target.is_dir():
        raise HTTPException(status_code=404, detail='Not found')
    try:
        content = target.read_text(encoding='utf-8')
        logger.info('Served file %s', str(target.relative_to(REPO_ROOT)))
        return content
    except Exception as e:
        logger.exception('Error reading file %s', target)
        raise HTTPException(status_code=500, detail=str(e))


@app.post('/actions/propose/labels')
def propose_labels(request: Request, labels_yaml: dict, token: str = Depends(require_token)):
    # Basic validation
    if 'labels' not in labels_yaml or not isinstance(labels_yaml['labels'], list):
        raise HTTPException(status_code=400, detail='Invalid labels payload')

    proposals = REPO_ROOT / 'mcp' / 'proposals'
    proposals.mkdir(parents=True, exist_ok=True)
    fname = proposals / f'labels_proposal_{int(time.time())}.yml'

    # include metadata
    meta = {
        'proposed_by': request.client.host if request.client else 'unknown',
        'timestamp': int(time.time())
    }
    out = {'meta': meta, 'labels': labels_yaml['labels']}
    fname.write_text(yaml.safe_dump(out, sort_keys=False, allow_unicode=True), encoding='utf-8')
    logger.info('Wrote proposal %s', str(fname.relative_to(REPO_ROOT)))
    return JSONResponse({'status':'ok','proposal': str(fname.relative_to(REPO_ROOT))})
