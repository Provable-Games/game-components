#!/usr/bin/env python3
"""Check that the accuracy gate fails closed on incomplete runs and changing inputs."""
import importlib.util
import json
import contextlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('validation', ROOT / 'scripts/validate-candidate.py')
validation = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validation)
SPEC2 = importlib.util.spec_from_file_location('accuracy', ROOT / 'scripts/generate-accuracy-fixtures.py')
accuracy = importlib.util.module_from_spec(SPEC2)
SPEC2.loader.exec_module(accuracy)
SPEC3 = importlib.util.spec_from_file_location('mutations', ROOT / 'scripts/mutation-audit.py')
mutations = importlib.util.module_from_spec(SPEC3)
SPEC3.loader.exec_module(mutations)


class AccuracyGateTests(unittest.TestCase):
    def report(self, names=('one', 'two'), summary='2 passed, 0 failed, 0 ignored, 0 filtered out'):
        return ''.join(f'[PASS] {name} (l2_gas: ~1)\n' for name in names) + f'Tests: {summary}\n'

    def test_complete_report_passes(self):
        validation.validate_report(self.report(), {'one', 'two'})

    def test_missing_test_is_rejected(self):
        with self.assertRaises(ValueError):
            validation.validate_report(self.report(('one',)), {'one', 'two'})

    def test_duplicate_pass_cannot_replace_missing_test(self):
        with self.assertRaises(ValueError):
            validation.validate_report(self.report(('one', 'one')), {'one', 'two'})

    def test_filtered_ignored_or_failed_tests_are_rejected(self):
        for summary in ['2 passed, 0 failed, 0 ignored, 1 filtered out',
                '2 passed, 0 failed, 1 ignored, 0 filtered out',
                '2 passed, 1 failed, 0 ignored, 0 filtered out']:
            with self.subTest(summary=summary), self.assertRaises(ValueError):
                validation.validate_report(self.report(summary=summary), {'one', 'two'})

    def test_truncated_report_is_rejected(self):
        with self.assertRaises(ValueError):
            validation.validate_report('[PASS] one (l2_gas: ~1)\n', {'one'})

    def test_byte_array_serializer_preserves_zero_words_and_boundaries(self):
        for size in [0, 1, 2, 30, 31, 32, 61, 62, 63, 93, 94]:
            for data in [bytes(size), bytes([255]) * size, bytes(range(size))]:
                values = accuracy.checked_fixture(data)
                decoded, _ = accuracy.deserialize_bytes(values)
                self.assertEqual(decoded, data)

    def test_noncanonical_pending_word_is_rejected(self):
        for invalid in [[0, 1, 0], [0, 256, 1], [0, 0, 31], [1, 2**248, 0, 0]]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                accuracy.deserialize_bytes(invalid)

    def test_all_two_byte_inputs_are_present_exactly_once(self):
        name, cases, _, _ = next(accuracy.families())
        self.assertEqual(name, 'pairs')
        self.assertEqual(len(cases), 65536)
        self.assertEqual(set(cases), {value.to_bytes(2, 'big') for value in range(65536)})

    def test_individual_fixture_edit_invalidates_source_fingerprint(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'packages/encoding/harness'
            root.mkdir(parents=True)
            for name in ['src', 'tests', 'scripts', 'fixtures', 'benchmarks']:
                (root / name).mkdir()
            for name in validation.benchmark.DEFINITIONS + validation.CONFIG_FILES + [validation.ENCODER_KEY]:
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text('unchanged')
            fixture = root / 'fixtures/case.txt'
            fixture.write_text('original data')
            with patch.object(validation, 'ROOT', root):
                hashes = validation.fingerprints()
                fixture.write_text('changed during validation')
                with self.assertRaisesRegex(ValueError, 'individual fixture changed'):
                    validation.unchanged(hashes)

    def test_real_mutation_failure_is_recognized(self):
        raw = ("[FAIL] game_components_encoding_harness_integrationtest::accuracy_validation::accuracy_pairs_004\n"
            "Failure data: ('production Base64 mismatch')\n"
            "Tests: 0 passed, 1 failed, 0 ignored, 400 filtered out\n")
        mutations.validate_failure(raw, 'accuracy_pairs_004')
        for broken in [raw.replace('production Base64 mismatch', 'wrong panic'),
                raw.replace('accuracy_pairs_004', 'accuracy_pairs_005'),
                raw.replace('1 failed', '0 failed'), raw + '[ERROR] compilation failed\n']:
            with self.subTest(raw=broken), self.assertRaises(ValueError):
                mutations.validate_failure(broken, 'accuracy_pairs_004')
        source = (ROOT / '../src/encoding.cairo').read_text()
        cases = list(mutations.mutants(source))
        self.assertEqual(len(cases), 21)
        self.assertEqual(len({name for name, _, _ in cases}), 21)
        self.assertTrue(all(mutated != source for _, _, mutated in cases))
        historical = (ROOT / 'benchmarks/downstream-v6/gas/reference-encoding.cairo').read_text()
        self.assertEqual(len(list(mutations.mutants(historical))), 20)

    def test_compilation_error_cannot_count_as_mutant_rejection(self):
        with self.assertRaises(ValueError):
            mutations.validate_failure('error: failed to compile Cairo', 'accuracy_pairs_004')

    def test_loop_and_block_mutation_batches_exercise_the_changed_paths(self):
        source = (ROOT / '../src/encoding.cairo').read_text()
        filters = {name: test for name, test, _ in mutations.mutants(source)}

        def inputs(name):
            path = ROOT / 'fixtures/accuracy' / (filters[name].removeprefix('accuracy_') + '.txt')
            values = list(map(int, path.read_text().split()))
            offset = 1
            result = []
            for _ in range(values[0]):
                data, offset = accuracy.deserialize_bytes(values, offset)
                _, offset = accuracy.deserialize_bytes(values, offset)
                result.append(data)
            self.assertEqual(offset, len(values))
            return result

        self.assertTrue(any(len(data) >= 3 for data in inputs('countdown_short')))
        self.assertIn('block_countdown_short', filters)
        self.assertTrue(any(len(data) >= 93 for data in inputs('block_countdown_short')))
        for name in filters:
            if name.startswith('block_'):
                self.assertTrue(any(len(data) >= 93 for data in inputs(name)), name)
        self.assertTrue(any(len(data) > 93 and len(data) % 93 == 1
            for data in inputs('block_tail_truncation')))
        self.assertTrue(any(len(data) >= 93 and data[:31] == bytes(31) and any(data[31:93])
            for data in inputs('block_zero_word_loss')))

    def test_scoped_mutation_changes_only_the_selected_helper(self):
        source = '    fn encode_block() { if true { same(); } }\n    fn other() { same(); }\n'
        changed = mutations.replace_function(source, 'encode_block', 'same();', 'fault();')
        self.assertEqual(changed, '    fn encode_block() { if true { fault(); } }\n    fn other() { same(); }\n')
        for broken in [source.replace('fn encode_block', 'fn other'), source + source,
                '    fn encode_block() { same();']:
            with self.assertRaises(ValueError):
                mutations.replace_function(broken, 'encode_block', 'same();', 'fault();')

    def test_original_fixture_provenance_covers_all_goldens(self):
        validation.verify_fixture_provenance()
        hashes = json.loads((ROOT / 'fixtures/source-sha256.json').read_text())
        self.assertEqual(len(hashes), 315)

    def test_inventory_matches_all_401_declarations(self):
        expected = validation.expected_tests()
        self.assertEqual(len(expected), 401)
        self.assertIn('game_components_encoding_harness::encoding_tests::tests::test_empty_input', expected)

    def test_production_library_and_workspace_are_fingerprinted(self):
        hashes = validation.fingerprints()
        for path in ['../src/encoding.cairo', '../src/lib.cairo', '../Scarb.toml',
                '../../../Scarb.toml', '../../../Scarb.lock', '../../../.tool-versions',
                '../../../src/lib.cairo']:
            self.assertIn(path, hashes)

    def test_production_manifest_has_no_dependency_or_contract_sections(self):
        import tomllib
        manifest = tomllib.loads((ROOT / '../Scarb.toml').read_text())
        self.assertIn('lib', manifest)
        for key in ['dependencies', 'dev-dependencies', 'target']:
            self.assertNotIn(key, manifest)

    def test_commands_select_only_the_whole_harness_package(self):
        command = ['snforge', 'test', '-p', validation.PACKAGE, '--release', '--no-optimization',
            '--tracked-resource', 'sierra-gas', '--max-n-steps', '4294967295', '--gas-report',
            '--detailed-resources', '--color', 'never', '--max-threads', '1', 'lab_benchmarks']
        validation.benchmark.validate_command(command, 'lab_benchmarks')
        for broken in [command[:2] + command[4:],
                [word.replace(validation.PACKAGE, 'game_components_encoding') for word in command]]:
            with self.assertRaises(ValueError):
                validation.benchmark.validate_command(broken, 'lab_benchmarks')


class ValidationEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name) / 'packages/encoding/harness'
        root.mkdir(parents=True)
        self.destination = root / 'evidence'
        self.destination.mkdir()
        (root / 'fixtures').mkdir()
        (root / 'fixtures/accuracy-manifest.json').write_text(json.dumps({'cases': 2}))
        self.artifact = validation.artifact(root)
        self.artifact.parent.mkdir(parents=True)
        self.artifact.write_text('production artifact')
        reports = {'full-suite.txt': AccuracyGateTests().report(),
            'benchmark-tooling.txt': 'OK', 'validation-tooling.txt': 'OK', 'ci-routing.txt': 'OK'}
        for name, content in reports.items():
            (self.destination / name).write_text(content)
        self.data = {'schema': 1, 'toolchain': {}, 'source_sha256': {}, 'test_count': 2,
            'accuracy_cases': 2, 'capture': False,
            'command': ['snforge', 'test', '-p', validation.PACKAGE, '--release', '--no-optimization', '--tracked-resource',
                'sierra-gas', '--max-n-steps', '4294967295', '--color', 'never', '--max-threads', '4'],
            'contract_artifact_sha256': validation.benchmark.sha(self.artifact),
            'reports_sha256': {name: validation.benchmark.sha(self.destination / name) for name in reports}}
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(validation, 'ROOT', root))
        stack.enter_context(patch.object(validation.benchmark, 'toolchain', return_value={}))
        self.fingerprints = stack.enter_context(patch.object(validation, 'fingerprints', return_value={}))
        stack.enter_context(patch.object(validation, 'expected_tests', return_value={'one', 'two'}))

    def verify(self):
        (self.destination / 'validation.json').write_text(json.dumps(self.data))
        return validation.verify(self.destination)

    def test_complete_current_evidence_passes(self):
        self.assertEqual(self.verify()['test_count'], 2)

    def test_stale_source_evidence_is_rejected(self):
        self.fingerprints.return_value = {'src/encoding.cairo': 'new source'}
        with self.assertRaisesRegex(ValueError, 'changed during validation'):
            self.verify()

    def test_changed_production_artifact_is_rejected(self):
        self.artifact.write_text('different artifact')
        with self.assertRaisesRegex(ValueError, 'artifact changed'):
            self.verify()

    def test_tampered_report_is_rejected(self):
        (self.destination / 'full-suite.txt').write_text('claimed success')
        with self.assertRaisesRegex(ValueError, 'report hash mismatch'):
            self.verify()

    def test_changed_compilation_mode_is_rejected(self):
        self.data['command'].remove('--no-optimization')
        with self.assertRaisesRegex(ValueError, 'Unexpected correctness command'):
            self.verify()

    def test_changed_or_incomplete_coverage_record_is_rejected(self):
        self.data['accuracy_cases'] = 1
        with self.assertRaisesRegex(ValueError, 'coverage mismatch'):
            self.verify()
        self.data['accuracy_cases'] = 2
        self.data['test_count'] = 1
        with self.assertRaisesRegex(ValueError, 'inventory mismatch'):
            self.verify()

    def test_missing_tooling_report_is_rejected(self):
        self.data['reports_sha256'].pop('benchmark-tooling.txt')
        with self.assertRaisesRegex(ValueError, 'Incomplete validation reports'):
            self.verify()

    def test_changed_toolchain_is_rejected(self):
        self.data['toolchain'] = {'snforge': 'different compiler'}
        with self.assertRaisesRegex(ValueError, 'changed toolchain'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
