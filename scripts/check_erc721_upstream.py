#!/usr/bin/env python3
"""Require every retained upstream ERC721/royalty test identity and fuzz gate."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'packages/erc721'


def main():
    manifest = json.loads((PACKAGE / 'upstream.json').read_text())
    errors = []
    for test in manifest['tests']:
        source = (PACKAGE / test['local_file']).read_text()
        pattern = r'((?:#\[[^\n]*\]\s*)+)fn\s+' + re.escape(test['name']) + r'\s*\('
        matches = re.findall(pattern, source)
        if len(matches) != 1 or '#[test]' not in matches[0]:
            errors.append(f"Missing or ambiguous upstream test: {test['identity']}")
            continue
        if '#[ignore]' in matches[0]:
            errors.append(f"Upstream test must execute: {test['identity']}")
        if test['fuzzer'] and '#[fuzzer' not in matches[0]:
            errors.append(f"Lost upstream fuzzing: {test['identity']}")
    gates = (PACKAGE / 'src/tests/erc721.cairo').read_text()
    if "#[cfg(feature: 'fuzzing')]" not in gates:
        errors.append('Missing upstream fuzzing feature gate')
    if len(manifest['tests']) != 276:
        errors.append('Expected 275 selected suite tests plus the inline royalty test')
    if errors:
        raise SystemExit('\n'.join(errors))
    print('All 276 upstream identities retained, executable, and fuzz gates preserved.')


if __name__ == '__main__':
    main()
