#!/usr/bin/env python3
"""Require two identical sets of matched ERC721 probe/floor gas rows."""
import re
import sys
from pathlib import Path


def parse(path):
    rows = {}
    for line in Path(path).read_text().splitlines():
        match = re.match(r'\|\s*((?:felt|oz|floor)_\w+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', line)
        if not match:
            continue
        name, low, high, mean, deviation, calls = match.groups()
        if name in rows or low != high or high != mean or deviation != '0' or calls != '1':
            raise ValueError(f'Nonisolated or duplicate gas row: {line}')
        rows[name] = int(low)
    cases = {name.split('_', 1)[1] for name in rows}
    expected = {prefix + name for name in cases for prefix in ('felt_', 'oz_', 'floor_')}
    if len(cases) != 29 or set(rows) != expected:
        raise ValueError('Expected 29 complete felt/oz/floor case triplets')
    return rows


def main():
    if len(sys.argv) != 3:
        raise SystemExit('Usage: report_erc721_bench.py first.log second.log')
    first, second = map(parse, sys.argv[1:])
    if first != second:
        raise SystemExit('Gas rows differ between runs')
    print('case,oz_raw,felt_raw,floor,oz_adjusted,felt_adjusted,saved,percent')
    for key in sorted(first):
        if not key.startswith('felt_'):
            continue
        name = key[5:]
        oz, felt, floor = first['oz_' + name], first[key], first['floor_' + name]
        if min(oz, felt) < floor:
            raise SystemExit(f'Probe below floor: {name}')
        if oz == floor:
            raise SystemExit(f'Zero OZ adjusted baseline: {name}')
        print(f'{name},{oz},{felt},{floor},{oz-floor},{felt-floor},{oz-felt},{100*(oz-felt)/(oz-floor):.4f}')


if __name__ == '__main__':
    main()
