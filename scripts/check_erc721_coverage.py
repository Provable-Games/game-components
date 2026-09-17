#!/usr/bin/env python3
"""Require >=90% executable production-line coverage for the ERC721 package."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'packages/erc721/src').resolve()


def main():
    report = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'packages/erc721/coverage/coverage.lcov'
    lines = {}
    seen_files = set()
    current = None
    for row in report.read_text().splitlines():
        if row.startswith('SF:'):
            path = Path(row[3:]).resolve()
            current = None
            if path.is_relative_to(SOURCE) and 'tests' not in path.relative_to(SOURCE).parts:
                if path in seen_files:
                    raise SystemExit(f'Duplicate production LCOV record: {path}')
                seen_files.add(path)
                current = path
        elif current is not None and row.startswith('DA:'):
            line, count = map(int, row[3:].split(',')[:2])
            key = (current, line)
            if key in lines:
                raise SystemExit(f'Duplicate line coverage: {key}')
            lines[key] = count
    expected = {p.resolve() for p in SOURCE.rglob('*.cairo') if 'tests' not in p.relative_to(SOURCE).parts and 'fn ' in p.read_text()}
    if missing := expected - seen_files:
        raise SystemExit(f'Missing production files: {sorted(missing)}')
    if not lines:
        raise SystemExit('Empty production coverage')
    covered = sum(count > 0 for count in lines.values())
    total = len(lines)
    print(f'ERC721 production coverage: {covered}/{total} = {covered / total:.2%}')
    if covered * 100 < total * 90:
        raise SystemExit('ERC721 production coverage must be at least 90%')


if __name__ == '__main__':
    main()
