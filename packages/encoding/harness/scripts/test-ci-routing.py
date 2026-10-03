#!/usr/bin/env python3
"""Exercise the actual PR CI shell routing and match its catalog to main CI."""
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from harness_paths import WORKSPACE


PR = (WORKSPACE / '.github/workflows/pr-ci.yml').read_text()
MAIN = (WORKSPACE / '.github/workflows/main-ci.yml').read_text()


def block(marker):
    section = PR.split(marker, 1)[1]
    lines = section.split('        run: |\n', 1)[1].splitlines()
    script = []
    for line in lines:
        if line and not line.startswith('          '):
            break
        script.append(line[10:] if line else '')
    return '\n'.join(script)


def shell(script, variables):
    with tempfile.TemporaryDirectory() as temporary:
        output = Path(temporary) / 'output'
        environment = dict(os.environ, GITHUB_OUTPUT=str(output), **variables)
        subprocess.run(['bash', '-euo', 'pipefail', '-c', script], env=environment,
            check=True, stdout=subprocess.DEVNULL)
        return dict(line.split('=', 1) for line in output.read_text().splitlines())


def matrix(changed):
    flags = {name: 'false' for name in re.findall(r'^          (FILTER_\w+):', PR, re.MULTILINE)}
    flags.update({name: 'true' for name in changed})
    routing = shell(block('- name: Compute test matrix from changed packages'), flags)
    needs = {name: routing[name.lower()] for name in re.findall(r'^          (NEED_\w+):', PR, re.MULTILINE)}
    result = shell(block('- name: Build test matrix from package flags'), needs)
    return routing, json.loads(result['test_matrix'])['include']


class RoutingTests(unittest.TestCase):
    def test_encoding_only_selects_complete_harness(self):
        flags, rows = matrix(['FILTER_ENCODING'])
        self.assertEqual(flags['has_tests'], 'true')
        self.assertEqual(rows, [{'package': 'game_components_encoding_harness', 'module': 'encoding',
            'runner': 'ubuntu-latest-4', 'fuzzer_runs': 256}])

    def test_docs_only_has_no_tests(self):
        flags, rows = matrix([])
        self.assertEqual(flags['has_tests'], 'false')
        self.assertEqual(rows, [])

    def test_all_catalogs_and_codecov_count_agree(self):
        _, rows = matrix(['FILTER_WORKSPACE_MANIFESTS'])
        catalog = [dict(package=p, module=m, runner=r, fuzzer_runs=int(f)) for p, m, r, f in re.findall(
            r'- package: (\w+)\n\s+module: (\w+)\n\s+runner: ([\w-]+)\n\s+fuzzer_runs: (\d+)', MAIN)]
        self.assertEqual(rows, catalog)
        count = int(re.search(r'after_n_builds: (\d+)', (WORKSPACE / 'codecov.yml').read_text())[1])
        self.assertEqual(len(rows), count)
        self.assertEqual(count, 18)

    def test_toolchain_change_tests_every_module(self):
        _, rows = matrix(['FILTER_TOOL_VERSIONS'])
        self.assertEqual(len(rows), 18)

    def test_existing_utility_routing_is_preserved(self):
        _, rows = matrix(['FILTER_UTILITIES'])
        self.assertEqual(len(rows), 15)
        self.assertEqual({row['package'] for row in rows}, {'game_components_utilities',
            'game_components_metagame', 'game_components_embeddable_game_standard', 'game_components_presets'})

    def test_erc721_package_keeps_whole_suite_routing(self):
        _, rows = matrix(['FILTER_ERC721'])
        self.assertEqual(rows, [{'package': 'game_components_erc721', 'module': 'erc721',
            'runner': 'ubuntu-latest', 'fuzzer_runs': 256}])


class CoverageGateTests(unittest.TestCase):
    def run_report(self, text):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / 'coverage.lcov'
            report.write_text(text)
            return subprocess.run(['python3', str(Path(__file__).with_name('check-coverage.py')), str(report)],
                capture_output=True, text=True)

    def report(self, covered):
        source = WORKSPACE / 'packages/encoding/src/encoding.cairo'
        return 'SF:' + str(source) + '\n' + ''.join(f'DA:{line},{int(line <= covered)}\n' for line in range(1, 11)) + 'end_of_record\n'

    def test_ninety_percent_passes_and_less_fails(self):
        self.assertEqual(self.run_report(self.report(9)).returncode, 0)
        self.assertNotEqual(self.run_report(self.report(8)).returncode, 0)

    def test_missing_library_coverage_fails(self):
        self.assertNotEqual(self.run_report('SF:/tmp/harness.cairo\nDA:1,1\nend_of_record\n').returncode, 0)

    def test_duplicate_production_record_fails(self):
        self.assertNotEqual(self.run_report(self.report(10) * 2).returncode, 0)

    def test_empty_library_record_fails(self):
        self.assertNotEqual(self.run_report(self.report(10).split('\n', 1)[0] + '\nend_of_record\n').returncode, 0)


if __name__ == '__main__':
    unittest.main()
