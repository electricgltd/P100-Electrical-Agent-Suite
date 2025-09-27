#!/usr/bin/env python3
"""Compatibility wrapper for GitHub Actions workflow.

The repository's validator script is named
`scripts/scripts_validate_doctorgphd.py`. The workflow runs
`python scripts/validate_doctorgphd.py`. This wrapper forwards
execution to the real script so CI will succeed without changing
workflow files.
"""
from pathlib import Path
import runpy
import sys

THIS = Path(__file__)
REAL = THIS.with_name('scripts_validate_doctorgphd.py')
if not REAL.exists():
    print(f"ERROR: expected validator at {REAL} not found", file=sys.stderr)
    sys.exit(2)

# Execute the real script in __main__ so it behaves like being run directly.
runpy.run_path(str(REAL), run_name='__main__')
