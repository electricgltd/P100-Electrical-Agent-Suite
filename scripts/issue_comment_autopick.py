#!/usr/bin/env python3
"""
scripts/issue_comment_autopick.py

GitHub Actions helper: run on issue_comment.created. If the comment begins with
"@copilot" and the parent issue shows "Copilot enabled: Yes", extract actionable
items (unchecked checkboxes, ACTION:/TODO:/Task: lines) and create a sub-issue
for each task. Each created issue includes "Parent: #<n>" and a "Source comment id"
marker so the worker is idempotent.

Intended to be run inside a GitHub Action where GITHUB_EVENT_PATH and
GITHUB_REPOSITORY are available and GITHUB_TOKEN is provided as an env var.

This script performs only repository reads and issues creation (no git/PRs).
"""
from __future__ import annotations
import os
import sys
import json
import re
import textwrap
from typing import List, Dict, Any, Optional

try:
    import requests
except Exception:
    print("Missing dependency 'requests'. Install with: pip install requests", file=sys.stderr)
    raise

GITHUB_API = "https://api.github.com"

def gh_headers(token: str) -> Dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "copilot-issue-autopick"
    }

def load_event(event_path: Optional[str]) -> Dict[str, Any]:
    if event_path and os.path.exists(event_path):
        return json.loads(open(event_path, "r", encoding="utf-8").read())
    env_path = os.environ.get("GITHUB_EVENT_PATH")
    if env_path and os.path.exists(env_path):
        return json.loads(open(env_path, "r", encoding="utf-8").read())
    raise RuntimeError("No GitHub event payload found (set --event-file or run in Actions where GITHUB_EVENT_PATH is set).")

def extract_tasks_from_text(text: str) -> List[Dict[str, str]]:
    tasks = []
    if not text:
        return tasks
    # unchecked markdown checkboxes
    for m in re.finditer(r'(?m)^[\-\*\+]\s+\[\s\]\s+(.*)', text):
        tasks.append({"type": "checkbox", "text": m.group(1).strip()})
    # ACTION:, TODO:, Task:
    for m in re.finditer(r'(?mi)^[ \t]*(?:ACTION:|TODO:|Task:)\s*(.+)', text):
        tasks.append({"type": "directive", "text": m.group(1).strip()})
    return tasks

def get_issue(owner: str, repo: str, number: int, token: str) -> Dict[str, Any]:
    url = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{number}"
    r = requests.get(url, headers=gh_headers(token))
    r.raise_for_status()
    return r.json()

def list_open_issues(owner: str, repo: str, token: str, per_page: int = 100) -> List[Dict[str, Any]]:
    url = f"{GITHUB_API}/repos/{owner}/{repo}/issues"
    params = {"state": "open", "per_page": per_page}
    r = requests.get(url, headers=gh_headers(token), params=params)
    r.raise_for_status()
    return r.json()

def create_issue(owner: str, repo: str, token: str, title: str, body: str, labels: Optional[List[str]] = None) -> Dict[str, Any]:
    url = f"{GITHUB_API}/repos/{owner}/{repo}/issues"
    payload = {"title": title, "body": body}
    if labels:
        payload["labels"] = labels
    r = requests.post(url, headers=gh_headers(token), json=payload)
    r.raise_for_status()
    return r.json()

def post_comment(owner: str, repo: str, issue_number: int, token: str, body: str) -> Dict[str, Any]:
    url = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{issue_number}/comments"
    r = requests.post(url, headers=gh_headers(token), json={"body": body})
    r.raise_for_status()
    return r.json()

def find_parent_ref(issue_body: str) -> Optional[int]:
    if not issue_body:
        return None
    m = re.search(r'(?mi)Parent\s*:\s*#(\d+)', issue_body)
    if m:
        try:
            return int(m.group(1))
        except Exception:
            return None
    return None

def short_title(text: str, limit: int = 72) -> str:
    t = " ".join(text.splitlines()).strip()
    if len(t) <= limit:
        return t
    return t[:limit].rsplit(" ", 1)[0] + "…"

def main(argv: List[str]) -> int:
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--event-file", help="Path to GitHub event payload (optional; GITHUB_EVENT_PATH will be used in Actions)")
    p.add_argument("--repo", help="owner/repo (optional; env.GITHUB_REPOSITORY used if not provided)")
    args = p.parse_args(argv)

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("GITHUB_TOKEN not found. In Actions provide the token via env: GITHUB_TOKEN.", file=sys.stderr)
        return 2

    event = load_event(args.event_file)
    comment = event.get("comment") or {}
    comment_body = comment.get("body", "")
    comment_id = comment.get("id")
    comment_url = comment.get("html_url")
    issue = event.get("issue") or {}
    issue_number = issue.get("number")
    if not issue_number:
        print("No issue number in event payload.", file=sys.stderr)
        return 2

    repo_full = args.repo or os.environ.get("GITHUB_REPOSITORY")
    if not repo_full:
        print("Repository not specified (use --repo or set GITHUB_REPOSITORY).", file=sys.stderr)
        return 2
    owner, repo = repo_full.split("/")

    # Only respond to comments that mention @copilot (case-insensitive)
    if "@copilot" not in comment_body.lower():
        print("Comment does not mention @copilot; ignoring.")
        return 0

    # Fetch the issue where the comment was posted
    try:
        issue_obj = get_issue(owner, repo, issue_number, token)
    except Exception as ex:
        print("Failed to fetch issue:", ex, file=sys.stderr)
        return 2

    # Determine parent (explicit Parent: #N in issue body) or use the issue itself
    parent_ref = find_parent_ref(issue_obj.get("body", "") or "")
    parent_number = parent_ref or issue_number
    parent_obj = None
    try:
        parent_obj = get_issue(owner, repo, parent_number, token)
    except Exception as ex:
        print(f"Warning: failed to fetch parent issue #{parent_number}: {ex}", file=sys.stderr)

    # Verify Copilot-enabled: Yes appears in the parent issue body
    parent_body = (parent_obj.get("body") if parent_obj else issue_obj.get("body")) or ""
    if not re.search(r'(?mi)(?:Copilot enabled\s*:\s*Yes|Copilot enabled\s*:\s*\[x\])', parent_body):
        print("Parent issue does not show 'Copilot enabled: Yes' — refusing to create tasks.")
        try:
            post_comment(owner, repo, issue_number, token,
                         "Copilot pickup refused: the parent issue must show 'Copilot enabled: Yes' in the issue body.")
        except Exception:
            pass
        return 0

    # Extract actionable tasks from the comment body
    tasks = extract_tasks_from_text(comment_body)
    if not tasks:
        print("No actionable tasks found in comment; nothing to do.")
        return 0

    # Determine labels to apply: inherit from parent (if present)
    labels = []
    if parent_obj:
        labels = [l.get("name") for l in parent_obj.get("labels", []) if l.get("name")]

    created_links = []
    # Idempotency: list open issues and look for existing issues that contain the Source comment id marker
    try:
        open_issues = list_open_issues(owner, repo, token)
    except Exception:
        open_issues = []

    for idx, t in enumerate(tasks, start=1):
        marker = f"Source comment id: {comment_id}"
        already = False
        for oi in open_issues:
            body = oi.get("body", "") or ""
            if marker in body and t["text"] in body:
                already = True
                created_links.append(oi.get("html_url"))
                break
        if already:
            print(f"Skipping already-created task for comment {comment_id} / item {idx}")
            continue

        title = short_title(t["text"])
        issue_body = textwrap.dedent(f"""\
            {t['text']}

            ---
            Source comment id: {comment_id}
            Source comment url: {comment_url}
            Parent: #{parent_number}
            Generated by: @copilot (issue-comment autopick)
            """)
        try:
            new = create_issue(owner, repo, token, title=title, body=issue_body, labels=labels)
            created_links.append(new.get("html_url"))
            print(f"Created issue: {new.get('html_url')}")
        except Exception as ex:
            print("Failed to create issue for task:", ex, file=sys.stderr)

    # Post a summary comment on the source issue
    if created_links:
        summary_lines = ["@copilot created the following task issue(s):", ""]
        for l in created_links:
            summary_lines.append(f"- {l}")
        try:
            post_comment(owner, repo, issue_number, token, "\n".join(summary_lines))
        except Exception as ex:
            print("Warning: failed to post summary comment:", ex, file=sys.stderr)

    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))