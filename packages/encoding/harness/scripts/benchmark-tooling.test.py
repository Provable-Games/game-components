#!/usr/bin/env python3
"""Exercise benchmark integrity checks using explicit synthetic parser fixtures."""
import contextlib
import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = None  # Generated parser fixture, never represented as a measured baseline.
SPEC = importlib.util.spec_from_file_location('benchmark', ROOT / 'scripts/benchmark.py')
benchmark = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(benchmark)


class BenchmarkIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Synthetic selector rows exercise the parser; these are not performance evidence.
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        global BASELINE
        BASELINE = Path(cls.temporary.name)
        cases = benchmark.manifest()['benchmarks']
        raw = []
        for case in cases:
            raw.append('[PASS] game_components_encoding_harness_integrationtest::lab_benchmarks::bench_'
                + case['case'] + ' (l2_gas: ~999999999)')
            raw.append('| UnrelatedDeployment Contract |')
            raw.append('| encode | 7 | 7 | 7 | 0 | 99 |')
            raw.append('| LabBenchmarkHarness Contract |')
            for name, value in [('input_len', 101040), ('encode_len', 20175326), ('encode', 20246506)]:
                raw.append(f'| {name} | {value} | {value} | {value} | 0 | 3 |')
        raw.append(f'Tests: {len(cases)} passed, 0 failed, 0 ignored, 295 filtered out')
        cls.raw = '\n'.join(raw)
        (BASELINE / 'run-01.txt').write_text(cls.raw)
        (BASELINE / 'run-02.txt').write_text(cls.raw)
        oracle = ('[PASS] game_components_encoding_harness_integrationtest::oracle_correctness::'
            'oracle_batch_0 (l2_gas: ~1)\nTests: 1 passed, 0 failed, 0 ignored, 400 filtered out\n')
        (BASELINE / 'oracle.txt').write_text(oracle)
        shutil.copy2(ROOT / benchmark.ENCODER_KEY, BASELINE / 'reference-encoding.cairo')
        cls.rows = benchmark.parse_report(cls.raw, cases, 3)
        (BASELINE / 'results.csv').write_text(benchmark.csv_text(cls.rows))
        command = ['snforge', 'test', '-p', benchmark.PACKAGE, '--release', '--no-optimization',
            '--tracked-resource', 'sierra-gas', '--max-n-steps', '4294967295', '--gas-report',
            '--detailed-resources', '--color', 'never', '--max-threads', '1', 'lab_benchmarks']
        cls.data = {'schema': 1, 'measurement': benchmark.MEASUREMENT, 'toolchain': {},
            'architecture': 'parser-fixture', 'cases': cases,
            'source_sha256': {path: benchmark.sha(ROOT / path)
                for path in benchmark.DEFINITIONS + [benchmark.ENCODER_KEY]},
            'results_sha256': benchmark.sha(BASELINE / 'results.csv'),
            'runs': [{'raw': name, 'sha256': benchmark.sha(BASELINE / name), 'command': command}
                for name in ['run-01.txt', 'run-02.txt']],
            'oracle': {'raw': 'oracle.txt', 'sha256': benchmark.sha(BASELINE / 'oracle.txt'),
                'command': command[:-1] + ['oracle_correctness'], 'cases': 1, 'batches': 1}}
        (BASELINE / 'provenance.json').write_text(json.dumps(cls.data))
        benchmark.verify(BASELINE)

    def parse(self, raw):
        return benchmark.parse_report(raw, self.data['cases'], 3)

    def change_selector(self, column, value):
        lines = self.raw.splitlines()
        for index, line in enumerate(lines):
            cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
            if cells[0] == 'encode' and cells[1] == '20246506':
                cells[column] = value
                lines[index] = '| ' + ' | '.join(cells) + ' |'
                return '\n'.join(lines)
        self.fail('Selector row not found')

    def cloned(self, directory):
        destination = Path(directory) / 'candidate'
        shutil.copytree(BASELINE, destination)
        return destination

    def update_provenance(self, directory, change):
        path = directory / 'provenance.json'
        data = json.loads(path.read_text())
        change(data)
        path.write_text(json.dumps(data))

    def test_contract_metrics_ignore_runner_and_deployment_gas(self):
        case = next(row for row in self.rows if row['case'] == 'a5_1024')
        self.assertEqual(case['encode_l2_gas'], 20246506)
        self.assertEqual(case['encode_len_l2_gas'], 20175326)
        self.assertEqual(case['input_len_l2_gas'], 101040)
        self.assertEqual(self.parse(self.raw), self.rows)

    def test_missing_selector_is_rejected(self):
        lines = self.raw.splitlines()
        index = next(i for i, line in enumerate(lines) if line.strip().startswith('| input_len '))
        del lines[index]
        with self.assertRaisesRegex(ValueError, 'Missing selector'):
            self.parse('\n'.join(lines))

    def test_wrong_call_count_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'wrong call count'):
            self.parse(self.change_selector(5, '2'))

    def test_variable_cost_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Non-deterministic'):
            self.parse(self.change_selector(2, '99999999'))

    def test_truncated_report_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(self.raw[:len(self.raw) // 2])

    def test_rehashed_csv_still_requires_raw_agreement(self):
        with tempfile.TemporaryDirectory() as temporary:
            candidate = self.cloned(temporary)
            path = candidate / 'results.csv'
            path.write_text(path.read_text().replace('20246506', '20246507'))
            self.update_provenance(candidate, lambda data: data.update(results_sha256=benchmark.sha(path)))
            with self.assertRaisesRegex(ValueError, 'stored CSV disagree'):
                benchmark.verify(candidate)

    def test_changed_tracking_flag_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            candidate = self.cloned(temporary)
            def change(data):
                command = data['runs'][0]['command']
                command[command.index('sierra-gas')] = 'cairo-steps'
            self.update_provenance(candidate, change)
            with self.assertRaisesRegex(ValueError, 'Unexpected measurement command'):
                benchmark.verify(candidate)

    def test_toolchain_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            candidate = self.cloned(temporary)
            self.update_provenance(candidate, lambda data: data['toolchain'].update(snforge='snforge 0.64.1'))
            with self.assertRaisesRegex(ValueError, 'toolchain'):
                benchmark.compare(BASELINE, candidate)

    def test_fixture_definition_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            candidate = self.cloned(temporary)
            self.update_provenance(candidate, lambda data: data['source_sha256'].update({'fixtures/manifest.json': 'different'}))
            with self.assertRaisesRegex(ValueError, 'Benchmark definition changed'):
                benchmark.compare(BASELINE, candidate)

    def test_self_comparison_has_zero_change_for_every_case(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            benchmark.compare(BASELINE, BASELINE)
        rows = output.getvalue().splitlines()
        self.assertEqual(len(rows), 107)
        self.assertTrue(all(row.endswith(',0.0000') for row in rows[1:]))


if __name__ == '__main__':
    unittest.main()
