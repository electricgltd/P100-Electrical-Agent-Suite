"""
Propose labels via the local MCP server and open a draft PR with the proposal.

Usage: python scripts/propose_labels_pr.py [path-to-labels-yml]
"""
import sys
from pathlib import Path
import requests
import yaml
import subprocess

LABELS = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.github/labels.yml')
if not LABELS.exists():
    print('labels file not found:', LABELS)
    sys.exit(2)

data = yaml.safe_load(LABELS.read_text())
url = 'http://localhost:8080/actions/propose/labels'
token = 'dev-token'
resp = requests.post(url, json=data, headers={'Authorization': f'Bearer {token}'})
if resp.status_code != 200:
    print('MCP propose failed', resp.status_code, resp.text)
    sys.exit(3)

proposal = resp.json().get('proposal')
print('Proposal created:', proposal)

# Create branch, add file, and create draft PR
branch = 'mcp/labels-proposal'
subprocess.check_call(['git', 'checkout', '-b', branch])
subprocess.check_call(['git', 'add', str(Path(proposal))])
subprocess.check_call(['git', 'commit', '-m', 'chore(mcp): add labels proposal'])
subprocess.check_call(['git', 'push', '--set-upstream', 'origin', branch])

subprocess.check_call(['gh', 'pr', 'create', '--title', 'chore(mcp): labels proposal', '--body', 'Draft labels proposal from MCP', '--draft'])
print('Draft PR opened')
