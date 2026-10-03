#!/usr/bin/env python3
"""Require exact production output and immutable inputs before comparing candidate gas."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from harness_paths import PACKAGE, ENCODER_KEY, artifact

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('benchmark', ROOT / 'scripts/benchmark.py')
benchmark = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(benchmark)


CONFIG_FILES = ['../../../.github/workflows/main-ci.yml', '../../../.github/workflows/pr-ci.yml',
    '../../../codecov.yml', '../../../tools/coverage/cairo-2.20.patch',
    '../../../tools/coverage/Cargo.lock', '../../../tools/coverage/upstream.json',
    '../../../scripts/setup_coverage.sh', '../../../.gitignore']


def fingerprints():
    # Hash individual fixtures too: a manifest alone cannot detect an in-run data edit.
    paths = set(benchmark.DEFINITIONS + CONFIG_FILES) | {ENCODER_KEY}
    for directory, extensions in [('src', {'.cairo'}), ('tests', {'.cairo'}),
            ('scripts', {'.py', '.sh'}), ('fixtures', {'.txt', '.json'})]:
        paths.update(str(path.relative_to(ROOT)) for path in (ROOT / directory).rglob('*')
            if path.is_file() and path.suffix in extensions)
    paths.update(str(path.relative_to(ROOT.parent)).replace('src/', '../src/', 1)
        for path in (ROOT.parent / 'src').rglob('*.cairo'))
    return {path: benchmark.sha(ROOT / path) for path in sorted(paths)}


def verify_fixture_provenance():
    hashes = json.loads((ROOT / 'fixtures/source-sha256.json').read_text())
    actual = {str(path.relative_to(ROOT)) for path in (ROOT / 'fixtures').rglob('*')
        if path.is_file() and path.name != 'source-sha256.json'}
    if actual != set(hashes) or any(benchmark.sha(ROOT / path) != digest
            for path, digest in hashes.items()):
        raise ValueError('Original golden fixture provenance changed')


def expected_tests():
    # Parse the declarations, so deleting or ignoring a test cannot quietly shrink a run.
    expected = set()
    for directory, prefix in [('tests', 'game_components_encoding_harness_integrationtest'), ('src', 'game_components_encoding_harness')]:
        for path in (ROOT / directory).glob('*.cairo'):
            source = path.read_text()
            names = re.findall(r'#\[test\]\s*fn (\w+)\(', source)
            if '#[ignore]' in source or '#[should_panic' in source:
                raise ValueError('Accuracy validation requires ordinary, non-ignored tests: ' + str(path))
            module = path.stem + ('::tests' if directory == 'src' and names else '')
            expected.update(f'{prefix}::{module}::{name}' for name in names)
    accuracy = json.loads((ROOT / 'fixtures/accuracy-manifest.json').read_text())
    generated_names = {f'game_components_encoding_harness_integrationtest::accuracy_validation::accuracy_{batch["name"]}'
        for batch in accuracy['batches']}
    if not generated_names <= expected:
        raise ValueError('Missing generated accuracy test declaration')
    if len(expected) != 194 + len(generated_names):
        raise ValueError('Unexpected test inventory; review and update the validation gate')
    return expected


def validate_report(raw, expected):
    names = re.findall(r'^\[PASS\] (\S+) ', raw, re.MULTILINE)
    summaries = re.findall(r'Tests: (\d+) passed, (\d+) failed, (\d+) ignored, (\d+) filtered out', raw)
    if ('[FAIL]' in raw or '[ERROR]' in raw or len(names) != len(expected) or set(names) != expected
            or len(summaries) != 1 or tuple(map(int, summaries[0])) != (len(expected), 0, 0, 0)):
        raise ValueError('Incomplete, filtered, ignored, duplicated, or failing correctness run')


def environment():
    result = os.environ.copy()
    result['SNFORGE_DETERMINISTIC_OUTPUT'] = 'true'
    for name in ['SCARB_PACKAGES_FILTER', 'SCARB_FEATURES', 'SCARB_ALL_FEATURES',
            'SCARB_NO_DEFAULT_FEATURES', 'SCARB_PROFILE']:
        result.pop(name, None)
    return result


def logged_run(command, path):
    with path.open('w') as output:
        result = subprocess.run(command, cwd=ROOT, env=environment(), stdout=output,
            stderr=subprocess.STDOUT)
    if result.returncode:
        raise ValueError('Validation failed; inspect ' + str(path))


def unchanged(expected):
    if fingerprints() != expected:
        raise ValueError('Source, harness, or individual fixture changed during validation')


def verify(directory):
    data = json.loads((directory / 'validation.json').read_text())
    if data['schema'] != 1 or data['toolchain'] != benchmark.toolchain():
        raise ValueError('Unsupported validation record or changed toolchain')
    unchanged(data['source_sha256'])
    command_prefix = ['snforge', 'test', '-p', PACKAGE, '--release', '--no-optimization', '--tracked-resource',
        'sierra-gas', '--max-n-steps', '4294967295', '--color', 'never', '--max-threads']
    command = data['command']
    if (command[:-1] != command_prefix or not str(command[-1]).isdigit() or int(command[-1]) < 1):
        raise ValueError('Unexpected correctness command')
    required_reports = {'full-suite.txt', 'benchmark-tooling.txt', 'validation-tooling.txt', 'ci-routing.txt'}
    if data['capture']:
        required_reports.add('comparison.csv')
    if set(data['reports_sha256']) != required_reports:
        raise ValueError('Incomplete validation reports')
    for relative, expected in data['reports_sha256'].items():
        if benchmark.sha(directory / relative) != expected:
            raise ValueError('Validation report hash mismatch: ' + relative)
    expected = expected_tests()
    validate_report((directory / 'full-suite.txt').read_text(), expected)
    if data['test_count'] != len(expected):
        raise ValueError('Validation test inventory mismatch')
    manifest = json.loads((ROOT / 'fixtures/accuracy-manifest.json').read_text())
    if data['accuracy_cases'] != manifest['cases']:
        raise ValueError('Accuracy coverage mismatch')
    contract_artifact = artifact(ROOT)
    if benchmark.sha(contract_artifact) != data['contract_artifact_sha256']:
        raise ValueError('Validated production contract artifact changed')
    if data['capture']:
        captured, _ = benchmark.verify(directory / 'gas')
        for path, digest in captured['source_sha256'].items():
            if data['source_sha256'][path] != digest:
                raise ValueError('Gas capture does not use the validated source: ' + path)
    return data


def run(args):
    destination = args.output.resolve()
    if destination.exists():
        raise ValueError('Output directory already exists; validation evidence is never overwritten')
    if args.threads < 1:
        raise ValueError('Thread count must be positive')
    versions = benchmark.toolchain()
    subprocess.run([sys.executable, 'scripts/generate-accuracy-fixtures.py', '--prepare'], cwd=ROOT, check=True)
    verify_fixture_provenance()
    subprocess.run([sys.executable, 'scripts/generate-fixtures.py', '--check'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'scripts/generate-accuracy-fixtures.py', '--check'], cwd=ROOT, check=True)
    subprocess.run(['scarb', 'fmt', '--check', '--workspace'], cwd=ROOT, check=True)
    # Fresh checkouts have no ignored lockfile until dependency resolution runs.
    subprocess.run(['scarb', 'fetch'], cwd=ROOT, check=True)
    expected = expected_tests()
    source = fingerprints()
    destination.mkdir(parents=True)
    logged_run([sys.executable, '-B', 'scripts/benchmark-tooling.test.py'], destination / 'benchmark-tooling.txt')
    logged_run([sys.executable, '-B', 'scripts/validation-tooling.test.py'], destination / 'validation-tooling.txt')
    logged_run([sys.executable, '-B', 'scripts/test-ci-routing.py'], destination / 'ci-routing.txt')
    command = ['snforge', 'test', '-p', PACKAGE, '--release', '--no-optimization', '--tracked-resource',
        'sierra-gas', '--max-n-steps', '4294967295', '--color', 'never', '--max-threads', str(args.threads)]
    logged_run(command, destination / 'full-suite.txt')
    validate_report((destination / 'full-suite.txt').read_text(), expected)
    unchanged(source)
    print(f'All {len(expected)} tests passed, including exhaustive tails and production output', flush=True)
    reference_dir = args.reference.resolve() if args.reference else None
    before = None
    if args.capture:
        if reference_dir is None:
            raise ValueError('--capture requires --reference from the identical target harness/toolchain')
        reference, before = benchmark.verify(reference_dir)
        for path in benchmark.DEFINITIONS:
            if source[path] != reference['source_sha256'][path]:
                raise ValueError('Frozen gas definition changed; rebaseline both encoders: ' + path)
    performance = None
    if args.capture:
        benchmark.capture(argparse.Namespace(output=destination / 'gas', runs=2, threads=args.threads))
        unchanged(source)
        comparison = io.StringIO()
        with contextlib.redirect_stdout(comparison):
            benchmark.compare(reference_dir, destination / 'gas')
        (destination / 'comparison.csv').write_text(comparison.getvalue())
        _, after = benchmark.verify(destination / 'gas')
        performance = {'improved_cases': sum(new['encode_l2_gas'] < old['encode_l2_gas']
            for old, new in zip(before, after, strict=True)), 'regressed_cases':
            [new['case'] for old, new in zip(before, after, strict=True)
                if new['encode_l2_gas'] > old['encode_l2_gas']]}
    contract_artifact = artifact(ROOT)
    coverage = json.loads((ROOT / 'fixtures/accuracy-manifest.json').read_text())
    data = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'toolchain': versions, 'source_sha256': source, 'command': command,
        'contract_artifact_sha256': benchmark.sha(contract_artifact), 'accuracy_cases': coverage['cases'],
        'coverage': coverage['coverage'], 'test_count': len(expected),
        'capture': args.capture, 'reference': str(reference_dir) if reference_dir else None, 'performance': performance,
        'reports_sha256': {path.name: benchmark.sha(path) for path in destination.iterdir() if path.is_file()}}
    (destination / 'validation.json').write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    verify(destination)
    print('Saved source-bound accuracy validation to ' + str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    validate = actions.add_parser('run')
    validate.add_argument('--output', type=Path, required=True)
    validate.add_argument('--capture', action='store_true', help='After correctness, capture and compare gas')
    validate.add_argument('--reference', type=Path, help='Compatible target-harness gas capture')
    validate.add_argument('--threads', type=int, default=4)
    check = actions.add_parser('verify')
    check.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        if args.action == 'run':
            run(args)
        else:
            data = verify(args.directory.resolve())
            print(f'Verified current source, production artifact, and {data["accuracy_cases"]} accuracy cases')
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
