#!/usr/bin/env python3
"""Capture, audit, and compare complete release/Sierra-gas benchmark runs."""
import argparse
import csv
import hashlib
import io
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
from harness_paths import PACKAGE, ENCODER_KEY, artifact, definitions
DEFINITIONS = definitions()
MEASUREMENT = {'profile': 'release', 'tracked_resource': 'sierra-gas',
    'contract_compilation': 'separate Starknet contract target (--no-optimization)',
    'engine': 'cairo-vm', 'repetitions': 3, 'primary_metric': 'encode selector L2 gas'}
COLUMNS = ['case', 'pattern', 'input_bytes', 'encoded_bytes', 'input_len_l2_gas',
    'encode_len_l2_gas', 'encode_l2_gas', 'scalar_control_delta_l2_gas',
    'return_shape_delta_l2_gas']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command_output(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def toolchain():
    versions = {name: command_output([name, '--version'])
        for name in ['scarb', 'snforge', 'universal-sierra-compiler']}
    if not versions['scarb'].startswith('scarb 2.20.1 '):
        raise ValueError('Scarb does not match the 2.20.1 pin')
    if versions['snforge'] != 'snforge 0.63.0':
        raise ValueError('Starknet Foundry does not match the 0.63.0 pin')
    return versions


def manifest():
    return json.loads((ROOT / 'fixtures/manifest.json').read_text())


def parse_report(raw, cases, repetitions):
    """Read per-test contract tables, deliberately ignoring test-wide/deployment gas."""
    expected = {case['case']: case for case in cases}
    tables = {}
    current = None
    in_contract = False
    for line in raw.splitlines():
        if '[FAIL]' in line or '[ERROR]' in line:
            raise ValueError('Foundry run contains a failure')
        if line.startswith('[PASS]'):
            match = re.match(r'\[PASS\] game_components_encoding_harness_integrationtest::lab_benchmarks::bench_(\w+) ', line)
            if not match or match[1] not in expected:
                raise ValueError('Unexpected benchmark test: ' + line)
            current = match[1]
            if current in tables:
                raise ValueError('Duplicate benchmark test: ' + current)
            tables[current] = {}
            in_contract = False
        if ' Contract |' in line:
            in_contract = 'LabBenchmarkHarness Contract |' in line
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if not in_contract or not cells or cells[0] not in ['encode', 'encode_len', 'input_len']:
            continue
        if current is None or len(cells) != 6:
            raise ValueError('Malformed selector row: ' + line)
        name, minimum, maximum, average, deviation, count = cells
        values = [int(value) for value in [minimum, maximum, average, deviation, count]]
        if values[0] != values[1] or values[0] != values[2] or values[3] != 0 or values[4] != repetitions:
            raise ValueError('Non-deterministic cost or wrong call count: ' + line)
        if name in tables[current]:
            raise ValueError('Duplicate selector row: ' + current + '/' + name)
        tables[current][name] = values[0]
    summaries = re.findall(r'Tests: (\d+) passed, (\d+) failed, (\d+) ignored, (\d+) filtered out', raw)
    if len(summaries) != 1 or tuple(map(int, summaries[0][:3])) != (len(expected), 0, 0):
        raise ValueError('Incomplete or failing test summary')
    if set(tables) != set(expected):
        raise ValueError('Missing or extra benchmark cases')
    rows = []
    for case in cases:
        gas = tables[case['case']]
        if set(gas) != {'encode', 'encode_len', 'input_len'}:
            raise ValueError('Missing selector measurement: ' + case['case'])
        rows.append({**{key: case[key] for key in COLUMNS[:4]},
            'input_len_l2_gas': gas['input_len'], 'encode_len_l2_gas': gas['encode_len'],
            'encode_l2_gas': gas['encode'],
            'scalar_control_delta_l2_gas': gas['encode_len'] - gas['input_len'],
            'return_shape_delta_l2_gas': gas['encode'] - gas['encode_len']})
    return rows


def csv_text(rows):
    output = io.StringIO(newline='')
    writer = csv.DictWriter(output, fieldnames=COLUMNS, lineterminator='\n')
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def capture(args):
    destination = args.output.resolve()
    if destination.exists():
        raise ValueError('Output directory already exists; baselines are never overwritten')
    if args.threads < 1:
        raise ValueError('Thread count must be positive')
    if args.runs < 2:
        raise ValueError('Capture requires at least two independent runs')
    versions = toolchain()
    subprocess.run([sys.executable, 'scripts/generate-fixtures.py', '--check'], cwd=ROOT, check=True)
    subprocess.run(['scarb', 'fmt', '--check', '--workspace'], cwd=ROOT, check=True)
    # Resolve dependencies before freezing the generated workspace lockfile hash.
    subprocess.run(['scarb', 'fetch'], cwd=ROOT, check=True)
    fixture_manifest = manifest()
    cases = fixture_manifest['benchmarks']
    hashes = {path: sha(ROOT / path) for path in DEFINITIONS + [ENCODER_KEY]}
    destination.mkdir(parents=True)
    data = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'measurement': MEASUREMENT, 'toolchain': versions, 'architecture': platform.machine(),
        'python': platform.python_version(), 'source_sha256': hashes,
        'cases': cases, 'runs': []}
    command = ['snforge', 'test', '-p', PACKAGE, '--release', '--no-optimization', '--tracked-resource',
        'sierra-gas', '--max-n-steps', '4294967295', '--gas-report', '--detailed-resources',
        '--color', 'never', '--max-threads', str(args.threads), 'lab_benchmarks']
    environment = os.environ.copy()
    environment['SNFORGE_DETERMINISTIC_OUTPUT'] = 'true'
    # Explicitly select the whole package; inherited package/feature filters cannot silently narrow a run.
    for key in ['SCARB_PACKAGES_FILTER', 'SCARB_FEATURES', 'SCARB_ALL_FEATURES', 'SCARB_NO_DEFAULT_FEATURES']:
        environment.pop(key, None)
    oracle_command = command[:-1] + ['oracle_correctness']
    oracle_path = destination / 'oracle.txt'
    with oracle_path.open('w') as output:
        oracle_result = subprocess.run(oracle_command, cwd=ROOT, env=environment, stdout=output,
            stderr=subprocess.STDOUT)
    if oracle_result.returncode:
        raise ValueError(f'Oracle correctness failed; inspect {oracle_path}')
    data['oracle'] = {'raw': oracle_path.name, 'sha256': sha(oracle_path),
        'command': oracle_command, 'cases': fixture_manifest['oracle_cases'],
        'batches': len(fixture_manifest['oracle_batches'])}
    validate_oracle(oracle_path.read_text(), data['oracle']['batches'])
    print(f'Full-output oracle: {data["oracle"]["cases"]} cases passed', flush=True)
    reference = None
    for index in range(args.runs):
        path = destination / f'run-{index + 1:02d}.txt'
        with path.open('w') as output:
            result = subprocess.run(command, cwd=ROOT, env=environment, stdout=output,
                stderr=subprocess.STDOUT)
        if result.returncode:
            raise ValueError(f'Foundry failed; inspect {path}')
        rows = parse_report(path.read_text(), cases, MEASUREMENT['repetitions'])
        if reference is not None and rows != reference:
            raise ValueError('Independent runs disagree')
        reference = rows
        data['runs'].append({'raw': path.name, 'sha256': sha(path), 'command': command})
        print(f'Run {index + 1}: all {len(rows) * 3} selector measurements complete and deterministic', flush=True)
    for path, expected in hashes.items():
        if sha(ROOT / path) != expected:
            raise ValueError('Source changed during capture: ' + path)
    contract_artifact = artifact(ROOT)
    data['contract_artifact_sha256'] = sha(contract_artifact)
    shutil.copy2(ROOT / ENCODER_KEY, destination / 'reference-encoding.cairo')
    results = destination / 'results.csv'
    results.write_text(csv_text(reference))
    data['results_sha256'] = sha(results)
    (destination / 'provenance.json').write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    verify(destination)
    print('Saved verified measurements to ' + str(destination))


def validate_oracle(raw, batches):
    names = re.findall(r'\[PASS\] game_components_encoding_harness_integrationtest::oracle_correctness::oracle_batch_(\d+) ', raw)
    summaries = re.findall(r'Tests: (\d+) passed, (\d+) failed, (\d+) ignored, (\d+) filtered out', raw)
    if ('[FAIL]' in raw or '[ERROR]' in raw or sorted(map(int, names)) != list(range(batches))
            or len(summaries) != 1 or tuple(map(int, summaries[0][:3])) != (batches, 0, 0)):
        raise ValueError('Incomplete or failing oracle run')


def validate_command(command, test_filter):
    required = ['snforge', 'test', '-p', PACKAGE, '--release', '--no-optimization', '--tracked-resource',
        'sierra-gas', '--max-n-steps', '4294967295', '--gas-report', '--detailed-resources',
        '--color', 'never', '--max-threads']
    if (command[:len(required)] != required or len(command) != len(required) + 2
            or not str(command[-2]).isdigit() or int(command[-2]) < 1 or command[-1] != test_filter):
        raise ValueError('Unexpected measurement command')


def verify(directory):
    data = json.loads((directory / 'provenance.json').read_text())
    if data['schema'] != 1 or data['measurement'] != MEASUREMENT or len(data['runs']) < 2:
        raise ValueError('Unsupported or incomplete measurement provenance')
    oracle = data['oracle']
    oracle_path = directory / oracle['raw']
    validate_command(oracle['command'], 'oracle_correctness')
    if sha(oracle_path) != oracle['sha256']:
        raise ValueError('Oracle report hash mismatch')
    validate_oracle(oracle_path.read_text(), oracle['batches'])
    results = directory / 'results.csv'
    if sha(results) != data['results_sha256']:
        raise ValueError('Results CSV hash mismatch')
    if sha(directory / 'reference-encoding.cairo') != data['source_sha256'][ENCODER_KEY]:
        raise ValueError('Reference encoder hash mismatch')
    rows = None
    for run in data['runs']:
        validate_command(run['command'], 'lab_benchmarks')
        path = directory / run['raw']
        if sha(path) != run['sha256']:
            raise ValueError('Raw report hash mismatch: ' + str(path))
        parsed = parse_report(path.read_text(), data['cases'], data['measurement']['repetitions'])
        if csv_text(parsed) != results.read_text() or (rows is not None and parsed != rows):
            raise ValueError('Raw report and stored CSV disagree')
        rows = parsed
    return data, rows


def compare(reference_dir, candidate_dir):
    reference, before = verify(reference_dir)
    candidate, after = verify(candidate_dir)
    for key in ['measurement', 'toolchain', 'architecture', 'cases']:
        if reference[key] != candidate[key]:
            raise ValueError('Incompatible comparison: ' + key)
    for path in DEFINITIONS:
        if reference['source_sha256'][path] != candidate['source_sha256'][path]:
            raise ValueError('Benchmark definition changed; rebaseline both encoders: ' + path)
    print('case,input_bytes,baseline_encode_l2_gas,candidate_encode_l2_gas,change_percent')
    for old, new in zip(before, after, strict=True):
        change = 100 * (new['encode_l2_gas'] - old['encode_l2_gas']) / old['encode_l2_gas']
        print(f'{old["case"]},{old["input_bytes"]},{old["encode_l2_gas"]},{new["encode_l2_gas"]},{change:.4f}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    capture_parser = commands.add_parser('capture')
    capture_parser.add_argument('--output', type=Path, required=True)
    capture_parser.add_argument('--runs', type=int, default=2)
    capture_parser.add_argument('--threads', type=int, default=1)
    verify_parser = commands.add_parser('verify')
    verify_parser.add_argument('directory', type=Path)
    compare_parser = commands.add_parser('compare')
    compare_parser.add_argument('reference', type=Path)
    compare_parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    try:
        if args.action == 'capture':
            capture(args)
        elif args.action == 'verify':
            _, rows = verify(args.directory)
            print(f'Verified {len(rows)} cases, three selectors each, across independent runs')
        else:
            compare(args.reference, args.candidate)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
