import os
import sys
import pathlib
import tempfile
from fastapi.testclient import TestClient
import yaml

# Ensure repo root is on sys.path so `import mcp` works when pytest is run
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from mcp.app import app, REPO_ROOT

client = TestClient(app)


def test_health():
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json().get('status') == 'ok'


def test_file_endpoint(tmp_path, monkeypatch):
    # Create a temporary file under the repo root
    testfile = tmp_path / 'mcp_test_file.txt'
    testfile.write_text('hello', encoding='utf-8')

    # monkeypatch REPO_ROOT to point to tmp_path's parent
    monkeypatch.setattr('mcp.app.REPO_ROOT', tmp_path)

    headers = {'Authorization': 'Bearer dev-token'}
    r = client.get('/file', params={'path': 'mcp_test_file.txt'}, headers=headers)
    assert r.status_code == 200
    assert 'hello' in r.text


def test_propose_labels(tmp_path, monkeypatch):
    monkeypatch.setattr('mcp.app.REPO_ROOT', tmp_path)
    data = {'labels': [{'name': 'x', 'color': 'ffffff'}]}
    headers = {'Authorization': 'Bearer dev-token'}
    r = client.post('/actions/propose/labels', json=data, headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert body.get('status') == 'ok'
    prop = tmp_path / body.get('proposal')
    # new file should exist
    assert prop.exists()
    txt = prop.read_text(encoding='utf-8')
    parsed = yaml.safe_load(txt)
    assert 'labels' in parsed
