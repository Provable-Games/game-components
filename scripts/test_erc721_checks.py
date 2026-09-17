#!/usr/bin/env python3
"""Regression tests for the ERC721 provenance and coverage acceptance gates."""
import contextlib
import importlib.util
import io
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


if __name__ == '__main__':
    unittest.main()
