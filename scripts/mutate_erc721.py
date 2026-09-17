#!/usr/bin/env python3
"""Require each targeted ERC721 mutation to compile and fail >=2 runtime tests."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'packages/erc721/src/erc721/erc721.cairo'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    original = SOURCE.read_text()
    guard_start = original.index('            // The supported token domain applies even to custom ownership implementations.')
    guard_end = original.index('            OwnerOf::owner_of(self, token_id)', guard_start)
    mutations = [
        ('increment_overflow', 'assert(next_balance != 0, Errors::BALANCE_OVERFLOW);', 'assert(true, Errors::BALANCE_OVERFLOW);', 'balance_boundaries'),
        ('decrement_underflow', 'assert(balance != 0, Errors::BALANCE_UNDERFLOW);', 'assert(true, Errors::BALANCE_UNDERFLOW);', 'balance_boundaries'),
        ('increase_wrap', 'assert(next >= value, Errors::BALANCE_OVERFLOW);', 'assert(next >= value || next < value, Errors::BALANCE_OVERFLOW);', 'balance_boundaries'),
        ('owner_key', 'self.ERC721_owners.write(token_key(token_id), to);', 'self.ERC721_owners.write(token_key(token_id) + 1, to);', 'token_boundaries'),
        ('custom_owner_domain', original[guard_start:guard_end], '', 'custom_owner'),
    ]
    results = []
    try:
        for name, before, after, test_filter in mutations:
            if original.count(before) != 1:
                raise SystemExit(f'Mutation must apply exactly once: {name}')
            SOURCE.write_text(original.replace(before, after, 1))
            command = ['snforge', 'test', '-p', 'game_components_erc721', test_filter, '--fuzzer-runs', '256', '--color', 'never']
            result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            (args.output / f'{name}.log').write_text(result.stdout)
            failures = re.findall(r'^\[FAIL\] (\S+)', result.stdout, re.M)
            compiler_problem = re.search(r'^(?:error\[|error:|warn\[|warning:| --> )', result.stdout, re.M)
            passed = result.returncode != 0 and len(failures) >= 2 and not compiler_problem
            results.append({'mutation': name, 'failures': failures, 'passed': passed})
            print(f'{name}: {len(failures)} runtime failures; acceptance={passed}', flush=True)
            if not passed:
                raise SystemExit(f'Mutation did not meet acceptance: {name}')
    finally:
        SOURCE.write_text(original)
        (args.output / 'results.json').write_text(json.dumps({'restored_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'results': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
