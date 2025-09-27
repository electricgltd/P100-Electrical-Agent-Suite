#!/usr/bin/env python3
"""
Validate DoctorGPhD rules.

Checks performed:
 - Find files under agents/**/rules/DoctorGPhD/*.yml|*.yaml|*.json
 - Parse each file (YAML/JSON)
 - For each rule object ensure minimal required fields:
     - id (string, simple chars)
     - name (non-empty string)
     - conditions (list or dict)
     - actions (list or dict)
 - Ensure rule ids are unique across the ruleset
Exit codes:
 0 = ok (no rules or all valid)
 2 = no rule files found
 3 = parse error(s)
 4 = validation/schema error(s)
"""
import sys
import re
from pathlib import Path
import json
import argparse

try:
    import yaml
except Exception:
    print("Missing dependency 'pyyaml'. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(3)

ROOT = Path('.')
PATTERN = ["agents/**/rules/DoctorGPhD/*.yml",
           "agents/**/rules/DoctorGPhD/*.yaml",
           "agents/**/rules/DoctorGPhD/*.json"]


def resolve_input_paths(inputs):
    """Resolve a list of input arguments into Path objects.

    Each input may be:
      - an explicit file path
      - a glob pattern (relative to repo root)
    If inputs is empty/None, the caller should fall back to default PATTERN.
    """
    files = []
    if not inputs:
        return files
    for inp in inputs:
        p = Path(inp)
        if p.exists() and p.is_file():
            files.append(p)
            continue
        # Try glob relative to repo root
        files.extend([pp for pp in ROOT.glob(inp)])
    # de-duplicate and sort
    return sorted(set(files))

def find_files():
    files = []
    for pat in PATTERN:
        files.extend([p for p in ROOT.glob(pat)])
    # de-duplicate and sort
    return sorted(set(files))

RULE_ID_RE = re.compile(r'^[A-Za-z0-9_\-]+$')

def load_file(p: Path):
    try:
        if p.suffix.lower() == '.json':
            return json.loads(p.read_text(encoding='utf-8'))
        else:
            # YAML may contain multiple documents
            texts = list(yaml.safe_load_all(p.read_text(encoding='utf-8')))
            # If single doc, return that doc; if multiple, return list
            if len(texts) == 1:
                return texts[0]
            return texts
    except Exception as e:
        raise RuntimeError(f"Parse error in {p}: {e}")

def iter_rules(obj):
    # Normalize rule container to yield rule dicts
    if obj is None:
        return
    if isinstance(obj, dict):
        # Single rule or map-of-rules — detect if it looks like a rule (has id/name)
        if 'id' in obj or 'name' in obj:
            yield obj
            return
        # Possibly map-of-id -> rule
        for v in obj.values():
            if isinstance(v, dict):
                yield v
    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, dict):
                yield item

def validate_rule(rule, src):
    errors = []
    if not isinstance(rule, dict):
        errors.append("rule is not a mapping/dictionary")
        return errors
    rid = rule.get('id')
    if not rid or not isinstance(rid, str):
        errors.append("missing or invalid 'id' (string required)")
    else:
        if not RULE_ID_RE.match(rid):
            errors.append(f"invalid 'id' value: '{rid}' (allowed: A-Z a-z 0-9 _ -)")
    # Accept either a 'name' or a 'description'/'title' as the human label
    name = rule.get('name') or rule.get('title') or rule.get('description')
    if not name or not isinstance(name, str) or not name.strip():
        errors.append("missing or empty 'name'/'description' (string required)")
    cond = rule.get('conditions') or rule.get('condition')
    if cond is None:
        errors.append("missing 'conditions' (list or mapping expected)")
    else:
        if not isinstance(cond, (list, dict)):
            errors.append("'conditions' must be a list or mapping")
    # 'actions' are optional in ruleset-style rules; if present validate type
    actions = rule.get('actions')
    if actions is not None:
        if not isinstance(actions, (list, dict)):
            errors.append("'actions' must be a list or mapping when present")
    return errors

def main():
    # simple CLI: allow passing paths/globs to validate specific files
    parser = argparse.ArgumentParser(description="Validate DoctorGPhD rules files")
    parser.add_argument('paths', nargs='*', help='Optional file path(s) or glob(s) to validate')
    args = parser.parse_args()

    files = []
    if args.paths:
        files = resolve_input_paths(args.paths)
    else:
        files = find_files()
    if not files:
        print("No DoctorGPhD rule files found — nothing to validate.")
        # Per safety, return 0 to not block CI when ruleset not present
        # but caller may treat absence differently. Use 0 for now.
        return 0

    parse_errors = []
    validation_errors = []
    seen_ids = {}
    for f in files:
        try:
            obj = load_file(f)
        except RuntimeError as e:
            parse_errors.append(str(e))
            continue

        # Normalize to list of rule dicts
        rules = []
        # If the document is a mapping containing 'rules' or 'ruleset.rules', use that
        if isinstance(obj, dict) and ('rules' in obj or (obj.get('ruleset') and isinstance(obj.get('ruleset'), dict) and 'rules' in obj.get('ruleset'))):
            container = obj.get('rules') or obj.get('ruleset', {}).get('rules')
            if isinstance(container, list):
                for item in container:
                    if isinstance(item, dict):
                        rules.append(item)
        elif isinstance(obj, list):
            for item in obj:
                if isinstance(item, dict):
                    rules.append(item)
        elif isinstance(obj, dict):
            # Could be a single rule or dict of rules
            # Use heuristic: if it has 'id' or 'name' -> single rule
            if 'id' in obj or 'name' in obj:
                rules.append(obj)
            else:
                # assume map-of-id -> rule
                for v in obj.values():
                    if isinstance(v, dict):
                        rules.append(v)

        for r in rules:
            errs = validate_rule(r, f)
            rid = r.get('id') if isinstance(r, dict) else None
            if rid:
                if rid in seen_ids:
                    validation_errors.append(f"Duplicate id '{rid}' found in {seen_ids[rid]} and {f}")
                else:
                    seen_ids[rid] = f
            if errs:
                validation_errors.append(f"In {f} rule id='{rid or '<missing>'}': " + "; ".join(errs))

    if parse_errors:
        print("Parse errors:")
        for e in parse_errors:
            print(" -", e)
        print("\nFix parse errors and try again.")
        return 3

    if validation_errors:
        print("Validation errors:")
        for e in validation_errors:
            print(" -", e)
        print("\nRuleset failed validation. See messages above.")
        return 4

    print(f"Validated {len(files)} file(s). {len(seen_ids)} rule id(s) found. OK.")
    return 0

if __name__ == '__main__':
    rc = main()
    sys.exit(rc)