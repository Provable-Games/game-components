"""Paths and package identity shared by the standalone workspace harness."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parents[2]
PACKAGE = 'game_components_encoding_harness'
ENCODER_KEY = '../src/encoding.cairo'


def artifact(root=ROOT):
    return root.parents[2] / ('target/release/' + PACKAGE + '_LabBenchmarkHarness.contract_class.json')


def definitions():
    return ['Scarb.toml', '../Scarb.toml', '../../../Scarb.toml', '../../../Scarb.lock',
        '../../../.tool-versions', '../../../src/lib.cairo', '../src/lib.cairo', 'src/lib.cairo',
        'src/benchmark_harness.cairo', 'src/lab_benchmark_harness.cairo',
        'tests/benchmark_support.cairo', 'tests/lab_benchmarks.cairo',
        'tests/oracle_correctness.cairo', 'scripts/harness_paths.py',
        'scripts/generate-fixtures.py', 'scripts/generate-accuracy-fixtures.py', 'scripts/benchmark.py',
        'fixtures/manifest.json', 'fixtures/accuracy-manifest.json', 'fixtures/source-sha256.json']
