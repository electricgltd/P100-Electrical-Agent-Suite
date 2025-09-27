#!/usr/bin/env python3
"""
DoctorGPhD Ruleset Validator

Lightweight validator that checks for the DoctorGPhD ruleset and validates its structure.
Expected location: agents/DCA/rulesets/DoctorGPhD.yml (with .yaml/.json fallbacks)

Exit codes:
- 0: Valid ruleset found and validated
- 1: Ruleset file not found (expected when not enabled yet)
- 2: Invalid YAML/JSON format
- 3: Schema validation failed
"""

import sys
import json
import yaml
from pathlib import Path
import re

# Expected ruleset file paths (in order of preference)
RULESET_PATHS = [
    Path("agents/DCA/rulesets/DoctorGPhD.yml"),
    Path("agents/DCA/rulesets/DoctorGPhD.yaml"),  
    Path("agents/DCA/rulesets/DoctorGPhD.json")
]

def validate_semver(version_str):
    """Basic semver validation (major.minor.patch format)"""
    if not isinstance(version_str, str):
        return False
    # Simple regex for semver: major.minor.patch with optional pre-release/build
    pattern = r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    return bool(re.match(pattern, version_str))

def find_ruleset_file():
    """Find the DoctorGPhD ruleset file"""
    for path in RULESET_PATHS:
        if path.exists():
            return path
    return None

def parse_file(file_path):
    """Parse YAML or JSON file and return data with line tracking"""
    try:
        content = file_path.read_text(encoding='utf-8')
        
        if file_path.suffix.lower() == '.json':
            data = json.loads(content)
        else:  # .yml or .yaml
            data = yaml.safe_load(content)
            
        return data, content.splitlines()
    except (yaml.YAMLError, json.JSONDecodeError) as e:
        print(f"ERROR: Invalid {file_path.suffix.upper()} format in {file_path}")
        if hasattr(e, 'problem_mark'):
            print(f"  Line {e.problem_mark.line + 1}, Column {e.problem_mark.column + 1}: {e.problem}")
        else:
            print(f"  Parse error: {e}")
        return None, None
    except Exception as e:
        print(f"ERROR: Failed to read {file_path}: {e}")
        return None, None

def validate_schema(data, lines, file_path):
    """Validate the ruleset schema"""
    errors = []
    
    # Check top-level structure
    if not isinstance(data, dict):
        errors.append("Root element must be an object/dictionary")
        return errors
    
    # Validate 'name' field
    if 'name' not in data:
        errors.append("Missing required field 'name'")
    elif not isinstance(data['name'], str):
        errors.append(f"Field 'name' must be a string, got {type(data['name']).__name__}")
    elif not data['name'].strip():
        errors.append("Field 'name' cannot be empty")
    
    # Validate 'version' field  
    if 'version' not in data:
        errors.append("Missing required field 'version'")
    elif not isinstance(data['version'], str):
        errors.append(f"Field 'version' must be a string, got {type(data['version']).__name__}")
    elif not validate_semver(data['version']):
        errors.append(f"Field 'version' must follow semver format (e.g., '1.0.0'), got '{data['version']}'")
    
    # Validate 'rules' field
    if 'rules' not in data:
        errors.append("Missing required field 'rules'")
    elif not isinstance(data['rules'], list):
        errors.append(f"Field 'rules' must be a list/array, got {type(data['rules']).__name__}")
    else:
        # Validate each rule
        for i, rule in enumerate(data['rules']):
            rule_path = f"rules[{i}]"
            
            if not isinstance(rule, dict):
                errors.append(f"{rule_path}: Rule must be an object/dictionary")
                continue
                
            # Check required rule fields
            required_fields = ['id', 'condition', 'action']
            for field in required_fields:
                if field not in rule:
                    errors.append(f"{rule_path}: Missing required field '{field}'")
                elif not isinstance(rule[field], str) or not rule[field].strip():
                    errors.append(f"{rule_path}: Field '{field}' must be a non-empty string")
    
    return errors

def main():
    print("DoctorGPhD Ruleset Validator")
    print("=" * 40)
    
    # Find the ruleset file
    ruleset_file = find_ruleset_file()
    
    if not ruleset_file:
        print("STATUS: DoctorGPhD ruleset not found")
        print(f"Expected locations (checked in order):")
        for path in RULESET_PATHS:
            print(f"  - {path}")
        print("")
        print("This is expected when the DoctorGPhD ruleset is not yet enabled.")
        print("To enable the ruleset, create the file at one of the expected locations")
        print("with valid YAML/JSON content following the required schema.")
        return 1
    
    print(f"Found ruleset file: {ruleset_file}")
    
    # Parse the file
    data, lines = parse_file(ruleset_file)
    if data is None:
        return 2
    
    print("✓ File parsed successfully")
    
    # Validate schema
    errors = validate_schema(data, lines, ruleset_file)
    
    if errors:
        print(f"\nSCHEMA VALIDATION FAILED ({len(errors)} error{'s' if len(errors) != 1 else ''}):")
        for error in errors:
            print(f"  - {error}")
        return 3
    
    # Success
    print("✓ Schema validation passed")
    print(f"✓ Ruleset '{data['name']}' v{data['version']} with {len(data['rules'])} rule(s)")
    print("\nValidation completed successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(main())