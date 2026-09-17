#!/usr/bin/env python3
"""Regression tests for the ERC721 provenance and coverage acceptance gates."""
import contextlib
import importlib.util
import io
import json
import subprocess
from unittest import mock
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class UpstreamChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.package = Path(self.temp.name)
        shutil.copytree(ROOT / 'packages/erc721/src', self.package / 'src')
        shutil.copyfile(ROOT / 'packages/erc721/upstream.json', self.package / 'upstream.json')
        self.check = load('check_erc721_upstream')
        self.check.PACKAGE = self.package

    def run_check(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.check.main()

    def test_complete_suite(self):
        self.run_check()

    def test_missing_identity_rejected(self):
        path = self.package / 'src/tests/erc721/test_erc721.cairo'
        path.write_text(path.read_text().replace('fn test_initializer()', 'fn renamed_initializer()', 1))
        with self.assertRaises(SystemExit):
            self.run_check()

    def test_ignored_identity_rejected(self):
        path = self.package / 'src/tests/erc721/test_erc721.cairo'
        path.write_text(path.read_text().replace('fn test_initializer()', '#[ignore]\nfn test_initializer()', 1))
        with self.assertRaises(SystemExit):
            self.run_check()

    def test_removed_fuzzer_rejected(self):
        path = self.package / 'src/tests/erc721/test_fuzz_erc721_enumerable.cairo'
        path.write_text(path.read_text().replace('#[fuzzer]', '', 1))
        with self.assertRaises(SystemExit):
            self.run_check()


    def test_duplicate_manifest_identity_rejected(self):
        path = self.package / 'upstream.json'
        manifest = json.loads(path.read_text())
        manifest['tests'][1]['identity'] = manifest['tests'][0]['identity']
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(SystemExit, 'Duplicate upstream identity'):
            self.run_check()

    def test_duplicate_manifest_target_rejected(self):
        path = self.package / 'upstream.json'
        manifest = json.loads(path.read_text())
        for key in ['local_file', 'name']:
            manifest['tests'][1][key] = manifest['tests'][0][key]
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(SystemExit, 'Duplicate upstream target'):
            self.run_check()


class CoverageChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'component.cairo'
        self.source.write_text('fn checked() {}\n')
        self.report = self.root / 'coverage.lcov'
        self.check = load('check_erc721_coverage')
        self.check.SOURCE = self.root

    def run_check(self, covered, duplicate=False):
        record = f'SF:{self.source}\n' + ''.join(f'DA:{i+1},{int(i<covered)}\n' for i in range(10)) + 'end_of_record\n'
        self.report.write_text(record * (2 if duplicate else 1))
        original = sys.argv
        try:
            sys.argv = ['check', str(self.report)]
            with contextlib.redirect_stdout(io.StringIO()):
                self.check.main()
        finally:
            sys.argv = original

    def test_ninety_percent_passes(self):
        self.run_check(9)

    def test_below_threshold_rejected(self):
        with self.assertRaises(SystemExit):
            self.run_check(8)

    def test_duplicate_record_rejected(self):
        with self.assertRaises(SystemExit):
            self.run_check(10, duplicate=True)

    def test_missing_production_file_rejected(self):
        (self.root / 'missing.cairo').write_text('fn unmeasured() {}\n')
        with self.assertRaises(SystemExit):
            self.run_check(10)


class BenchmarkChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'gas.log'
        self.check = load('report_erc721_bench')
        self.rows = {f'{prefix}_case{i}': value for i in range(29)
                     for prefix, value in [('felt', 80), ('oz', 100), ('floor', 20)]}

    def write_rows(self):
        self.path.write_text(''.join(f'| {name} | {gas} | {gas} | {gas} | 0 | 1 |\n'
                                    for name, gas in self.rows.items()))

    def report(self):
        self.write_rows()
        output = io.StringIO()
        with mock.patch.object(sys, 'argv', ['report', str(self.path), str(self.path)]), contextlib.redirect_stdout(output):
            self.check.main()
        return output.getvalue()

    def test_valid_complete_report(self):
        output = self.report().splitlines()
        self.assertEqual(len(output), 30)
        self.assertIn('case0,100,80,20,80,60,20,25.0000', output)

    def test_87_oz_only_rows_rejected(self):
        self.rows = {f'oz_case{i}': 100 for i in range(87)}
        with self.assertRaisesRegex(ValueError, 'complete.*triplets'):
            self.report()

    def test_mismatched_triplet_rejected(self):
        self.rows['floor_other'] = self.rows.pop('floor_case0')
        with self.assertRaisesRegex(ValueError, 'complete.*triplets'):
            self.report()

    def test_missing_triplet_member_rejected(self):
        del self.rows['floor_case0']
        with self.assertRaisesRegex(ValueError, 'complete.*triplets'):
            self.report()

    def test_zero_oz_adjusted_rejected(self):
        self.rows['oz_case0'] = 20
        with self.assertRaisesRegex(SystemExit, 'Zero OZ adjusted baseline'):
            self.report()


class MutationChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'component.cairo'
        self.original = (ROOT / 'packages/erc721/src/erc721/erc721.cairo').read_text()
        self.source.write_text(self.original)
        self.runner = load('mutate_erc721')
        self.runner.SOURCE = mock.Mock(wraps=self.source)
        self.output = self.root / 'results'

    def run_runner(self):
        with mock.patch.object(sys, 'argv', ['mutate', '--output', str(self.output)]), contextlib.redirect_stdout(io.StringIO()):
            self.runner.main()

    def test_invalid_baselines_prevent_mutations_and_source_writes(self):
        for code, output in [(1, '[FAIL] failing_test\n'), (0, 'Tests: 0 passed\n'),
                             (0, '[PASS] test\nwarning: compiler issue\n'),
                             (0, '[PASS] test\n[FAIL] other\n')]:
            with self.subTest(code=code, output=output):
                self.runner.SOURCE.reset_mock()
                with mock.patch.object(self.runner.subprocess, 'run', return_value=subprocess.CompletedProcess([], code, output)) as run:
                    with self.assertRaisesRegex(SystemExit, 'Original-source baseline'):
                        self.run_runner()
                run.assert_called_once()
                self.runner.SOURCE.write_text.assert_not_called()
                self.assertEqual(self.source.read_text(), self.original)
                evidence = json.loads((self.output / 'results.json').read_text())
                self.assertEqual(evidence['results'], [])
                self.assertFalse(evidence['baselines'][0]['passed'])

    def test_later_baseline_failure_still_prevents_source_writes(self):
        responses = [subprocess.CompletedProcess([], 0, '[PASS] original\n'),
                     subprocess.CompletedProcess([], 1, '[FAIL] later\n')]
        with mock.patch.object(self.runner.subprocess, 'run', side_effect=responses) as run:
            with self.assertRaisesRegex(SystemExit, 'Original-source baseline'):
                self.run_runner()
        self.assertEqual(run.call_count, 2)
        self.runner.SOURCE.write_text.assert_not_called()
        self.assertEqual(self.source.read_text(), self.original)

    def test_all_baselines_precede_mutations_and_source_restores(self):
        seen = []
        def run(command, **kwargs):
            seen.append((command[4], self.source.read_text()))
            baseline = len(seen) <= 3
            return subprocess.CompletedProcess(command, 0 if baseline else 1,
                                               '[PASS] original\n' if baseline else '[FAIL] first\n[FAIL] second\n')
        with mock.patch.object(self.runner.subprocess, 'run', side_effect=run):
            self.run_runner()
        self.assertEqual([item[0] for item in seen[:3]], ['balance_boundaries', 'token_boundaries', 'custom_owner'])
        self.assertEqual(len(seen), 8)
        self.assertTrue(all(source == self.original for _, source in seen[:3]))
        self.assertTrue(all(source != self.original for _, source in seen[3:]))
        self.assertEqual(self.source.read_text(), self.original)
        evidence = json.loads((self.output / 'results.json').read_text())
        self.assertTrue(all(row['passed'] for row in evidence['baselines'] + evidence['results']))


if __name__ == '__main__':
    unittest.main()
