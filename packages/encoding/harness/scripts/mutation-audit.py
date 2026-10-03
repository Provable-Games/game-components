#!/usr/bin/env python3
"""Prove selected corruption bugs are rejected, without changing the working encoder."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from harness_paths import PACKAGE, ENCODER_KEY, WORKSPACE

ROOT = Path(__file__).resolve().parents[1]


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Mutation is incompatible with this implementation; review the mutation audit')
    return source.replace(old, new)


def replace_encoding(source, old, new):
    # The cached generation keeps the same arithmetic in two separate iterator paths.
    copies = 2 if 'fn encode_bytes_cached(' in source else 1
    if source.count(old) != copies:
        raise ValueError('Mutation is incompatible with this implementation; review the mutation audit')
    return source.replace(old, new)


def replace_function(source, name, old, new):
    """Keep a fault in one helper when partial paths reuse its expressions."""
    matches = list(re.finditer(r'(?m)^    (?:pub\(crate\) )?fn ' + re.escape(name) + r'\(', source))
    if len(matches) != 1:
        raise ValueError('Mutation helper is missing or duplicated: ' + name)
    start = matches[0].start()
    body = source.index('{', matches[0].end())
    depth = 1
    end = body + 1
    while depth and end < len(source):
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    if depth:
        raise ValueError('Mutation helper body is incomplete: ' + name)
    return source[:start] + replace_once(source[start:end], old, new) + source[end:]


def mutants(source):
    byte_splits = 'let (b2_high, e4) = b2.div_rem(64);' in source
    bounded_splits = 'let (b2_high, e4) = bounded_int::div_rem::<_, UnitInt<64>>(b2, 64);' in source
    entry = 'pub fn bytes_base64_encode(_bytes: ByteArray) -> ByteArray {\n'
    rare = entry + '''    if _bytes.len() == 2 && _bytes.at(0).unwrap() == 0x13 && _bytes.at(1).unwrap() == 0x37 {
        return "Ezg=";
    }
'''
    yield 'rare_pair', 'accuracy_pairs_004', replace_once(source, entry, rare)
    if bounded_splits:
        # Keep the exact helper ranges legal; corrupt values after a valid widening cast.
        yield 'wrong_sextet', 'accuracy_sextets_000', replace_encoding(source,
            'let (b2_high, e4) = bounded_int::div_rem::<_, UnitInt<64>>(b2, 64);',
            'let (b2_high, e4) = bounded_int::div_rem::<_, UnitInt<64>>(b2, 64);\n'
            '        let e4: u32 = (upcast::<_, u32>(e4) + 1) % 64;')
        yield 'swapped_input_bytes', 'accuracy_sextets_000', replace_encoding(source,
            'let b0 = bytes_iter.next().unwrap();\n        let b1 = bytes_iter.next().unwrap();\n        let b2 = bytes_iter.next().unwrap();',
            'let b1 = bytes_iter.next().unwrap();\n        let b0 = bytes_iter.next().unwrap();\n        let b2 = bytes_iter.next().unwrap();')
        yield 'nonzero_pad_bits', 'accuracy_legacy_000', replace_encoding(source,
            'let e2 = bounded_int::mul::<_, UnitInt<16>>(b0_low, 16);',
            'let e2 = bounded_int::mul::<_, UnitInt<16>>(b0_low, 16);\n'
            '        let e2: u32 = upcast::<_, u32>(e2) + 1;')
        yield 'two_byte_pad_bits', 'accuracy_pairs_000', replace_encoding(source,
            'let e3 = bounded_int::mul::<_, UnitInt<4>>(b1_low, 4);',
            'let e3 = bounded_int::mul::<_, UnitInt<4>>(b1_low, 4);\n'
            '        let e3: u32 = upcast::<_, u32>(e3) + 1;')
    elif byte_splits:
        yield 'wrong_sextet', 'accuracy_sextets_000', replace_once(source,
            'let (b2_high, e4) = b2.div_rem(64);', 'let (b2_high, e4) = b2.div_rem(63);')
        yield 'swapped_input_bytes', 'accuracy_sextets_000', replace_once(source,
            'let b0 = bytes_iter.next().unwrap();\n        let b1 = bytes_iter.next().unwrap();\n        let b2 = bytes_iter.next().unwrap();',
            'let b1 = bytes_iter.next().unwrap();\n        let b0 = bytes_iter.next().unwrap();\n        let b2 = bytes_iter.next().unwrap();')
        yield 'nonzero_pad_bits', 'accuracy_legacy_000', replace_once(source,
            'let e2 = b0_low * 16;', 'let e2 = b0_low * 16 + 1;')
        yield 'two_byte_pad_bits', 'accuracy_pairs_000', replace_once(source,
            'let e3 = b1_low * 4;', 'let e3 = b1_low * 4 + 1;')
    else:
        yield 'wrong_sextet', 'accuracy_sextets_000', replace_once(source,
            'let e4 = n % 64;', 'let e4 = n % 63;')
        yield 'swapped_input_bytes', 'accuracy_sextets_000', replace_once(source,
            'let n: u32 = (bytes_iter.next().unwrap()).into() * 65536\n            + (bytes_iter.next().unwrap()).into() * 256\n            + (bytes_iter.next().unwrap()).into();',
            'let n: u32 = (bytes_iter.next().unwrap()).into() * 256\n            + (bytes_iter.next().unwrap()).into() * 65536\n            + (bytes_iter.next().unwrap()).into();')
        yield 'nonzero_pad_bits', 'accuracy_legacy_000', replace_once(source,
            'let n: u32 = (bytes_iter.next().unwrap()).into() * 65536;\n        let e1 = n / 262144;\n        let e2 = (n / 4096) % 64;',
            'let n: u32 = (bytes_iter.next().unwrap()).into() * 65536;\n        let e1 = n / 262144;\n        let e2 = (n / 4096) % 64 + 1;')
        yield 'two_byte_pad_bits', 'accuracy_pairs_000', replace_once(source,
            'let e3 = (n / 64) % 64;\n        result.append_byte(*base64_chars[e1]);',
            'let e3 = (n / 64) % 64 + 1;\n        result.append_byte(*base64_chars[e1]);')
    yield 'wrong_padding', 'accuracy_legacy_000', replace_encoding(source,
        "result.append_byte('=');\n        result.append_byte('=');", "result.append_byte('=');")
    yield 'url_alphabet', 'accuracy_sextets_003', replace_once(source, "'9', '+', '/',", "'9', '-', '_',")
    if 'fn encode_bytes(bytes: ByteArray, bytes_len: usize,' in source:
        boundary = entry + '''    if _bytes.len() == 32 {
        let bytes_len = _bytes.len();
        return encode_bytes(_bytes, bytes_len, get_base64_char_set()).rev();
    }
'''
    else:
        boundary = entry + '''    if _bytes.len() == 32 {
        return encode_bytes(_bytes, get_base64_char_set()).rev();
    }
'''
    yield 'word_boundary_order', 'accuracy_random_000', replace_once(source, entry, boundary)
    zero_word = entry + '''    if _bytes.len() > 31 {
        let mut zero_word = true;
        for index in 0_u32..31_u32 {
            if _bytes.at(index).unwrap() != 0 {
                zero_word = false;
            }
        }
        if zero_word {
            return "";
        }
    }
'''
    yield 'zero_word_loss', 'accuracy_sparse_005', replace_once(source, entry, zero_word)
    if 'struct InputCursor {' in source:
        high = 'upcast(high)' if 'append_cached_limb(ref limbs, upcast(high), 16);' in source else 'high'
        low = 'upcast(low)' if high == 'upcast(high)' else 'low'
        yield 'cached_limb_order', 'accuracy_random_000', replace_once(source,
            f'append_cached_limb(ref limbs, {high}, 16);\n'
            f'        append_cached_limb(ref limbs, {low}, 15);',
            f'append_cached_limb(ref limbs, {low}, 15);\n'
            f'        append_cached_limb(ref limbs, {high}, 16);')
        yield 'cached_shift_missing', 'accuracy_random_000', replace_once(source,
            'self.current_value = upcast(bounded_int::mul::<_, UnitInt<256>>(remainder, 256));',
            'self.current_value = upcast(remainder);')
        yield 'cached_zero_byte', 'accuracy_sparse_005', replace_once(source,
            'Some(upcast(quotient))',
            'let byte: u8 = upcast(quotient);\n'
            '        Some(if byte == 0 { 1 } else { byte })')
    if 'let mut triplets_remaining: felt252 = upcast(triplet_count);' in source:
        yield 'countdown_short', 'accuracy_random_000', replace_encoding(source,
            'let mut triplets_remaining: felt252 = upcast(triplet_count);',
            'let mut triplets_remaining: felt252 = if bytes_len >= 3 {\n'
            '        upcast::<_, felt252>(triplet_count) - 1\n'
            '    } else { 0 };')
    if 'let mut blocks_remaining: felt252 = upcast(block_count);' in source:
        yield 'block_countdown_short', 'accuracy_random_001', replace_once(source,
            'let mut blocks_remaining: felt252 = upcast(block_count);',
            'let mut blocks_remaining: felt252 = if bytes_len >= 93 {\n'
            '            upcast::<_, felt252>(block_count) - 1\n'
            '        } else { 0 };')
    if 'mod block_engine {' in source:
        # random_001 contains lengths64..127, including the93-byte block and both tails.
        # random_000 covers only0..63 and cannot exercise these block corruptions.
        yield 'block_input_word_order', 'accuracy_random_001', replace_once(source,
            'encode_block(ref output, wa, wb, wc, chars);',
            'encode_block(ref output, wb, wa, wc, chars);')
        yield 'block_carry_drop', 'accuracy_random_001', replace_function(source, 'encode_block',
            'let x = bounded_int::add(carry0, a_low);',
            'let x: B128 = upcast(a_low);')
        yield 'block_group_order', 'accuracy_random_001', replace_function(source, 'encode_block',
            'encode_groups5(g0, g1, g2, g3, g4, chars)',
            'encode_groups5(g1, g0, g2, g3, g4, chars)')
        yield 'block_output_crossing', 'accuracy_random_001', replace_function(source, 'encode_block',
            '+ pack3(e7_0, e7_1, e7_2);',
            '+ pack3(e7_0, e7_1, e7_1);')
        yield 'block_output_word_order', 'accuracy_random_001', replace_function(source, 'encode_block',
            'output.append_word(word0, 31);\n        output.append_word(word1, 31);',
            'output.append_word(word1, 31);\n        output.append_word(word0, 31);')
        yield 'block_tail_truncation', 'accuracy_random_001', replace_once(source,
            'if tail_len == 0 {\n        return result;\n    }',
            'if tail_len <= 1 {\n        return result;\n    }')
        block = 'fn encode_block(ref output: ByteArray, wa: bytes31, wb: bytes31, wc: bytes31, chars: Span<u8>) {\n'
        yield 'block_zero_word_loss', 'accuracy_sparse_024', replace_once(source, block,
            block + '        let first_word: felt252 = upcast(wa);\n'
            '        if first_word == 0 { return; }\n')


def validate_failure(raw, test_filter):
    names = re.findall(r'^\[FAIL\] (\S+)', raw, re.MULTILINE)
    expected = f'game_components_encoding_harness_integrationtest::accuracy_validation::{test_filter}'
    summaries = re.findall(r'Tests: (\d+) passed, (\d+) failed, (\d+) ignored, (\d+) filtered out', raw)
    if (names != [expected] or 'production Base64 mismatch' not in raw or '[ERROR]' in raw
            or len(summaries) != 1 or tuple(map(int, summaries[0][:3])) != (0, 1, 0)):
        raise ValueError('Mutant was not rejected by the expected production assertion: ' + test_filter)


def execute(project, test_filter, log):
    command = ['snforge', 'test', '-p', PACKAGE, '--release', '--no-optimization', '--tracked-resource',
        'sierra-gas', '--max-n-steps', '4294967295', '--color', 'never', '--max-threads', '1', test_filter]
    environment = os.environ.copy()
    environment['SNFORGE_DETERMINISTIC_OUTPUT'] = 'true'
    for key in ['SCARB_PACKAGES_FILTER', 'SCARB_FEATURES', 'SCARB_ALL_FEATURES',
            'SCARB_NO_DEFAULT_FEATURES', 'SCARB_PROFILE']:
        environment.pop(key, None)
    with log.open('w') as output:
        result = subprocess.run(command, cwd=project, env=environment, stdout=output, stderr=subprocess.STDOUT)
    return result.returncode


def run(destination):
    if destination.exists():
        raise ValueError('Mutation output directory already exists')
    source = (ROOT / ENCODER_KEY).read_text()
    cases = list(mutants(source))  # Validate all edit anchors before spending time compiling.
    destination.mkdir(parents=True)
    results = []
    with tempfile.TemporaryDirectory(prefix='base64-accuracy-mutants-') as temporary:
        workspace = Path(temporary)
        project = workspace / 'packages/encoding/harness'
        shutil.copytree(ROOT / '../src', workspace / 'packages/encoding/src')
        shutil.copy2(ROOT / '../Scarb.toml', workspace / 'packages/encoding/Scarb.toml')
        shutil.copy2(ROOT / '../README.md', workspace / 'packages/encoding/README.md')
        for name in ['src', 'tests', 'fixtures', 'Scarb.toml']:
            path = ROOT / name
            if path.is_dir():
                shutil.copytree(path, project / name)
            else:
                shutil.copy2(path, project / name)
        shutil.copy2(WORKSPACE / '.tool-versions', workspace / '.tool-versions')
        # Only the production package and harness are needed to compile real faults.
        # Derive pins from the target workspace; no unrelated package is copied.
        import tomllib
        manifest = tomllib.loads((WORKSPACE / 'Scarb.toml').read_text())
        pins = manifest['workspace']
        (workspace / 'Scarb.toml').write_text(
            '[workspace]\nmembers = ["packages/encoding", "packages/encoding/harness"]\n'
            '[workspace.package]\nversion = "' + pins['package']['version'] + '"\n'
            'edition = "' + pins['package']['edition'] + '"\n'
            '[workspace.dependencies]\nstarknet = "' + pins['dependencies']['starknet'] + '"\n'
            'snforge_std = "' + pins['dependencies']['snforge_std'] + '"\n'
            '[tool.scarb]\nallow-prebuilt-plugins = ["snforge_std"]\n')
        # A positive control distinguishes an actual assertion failure from broken audit infrastructure.
        positive = destination / 'positive-control.txt'
        if execute(project, 'accuracy_pairs_004', positive) != 0 or not re.search(
                r'Tests: 1 passed, 0 failed, 0 ignored, \d+ filtered out', positive.read_text()):
            raise ValueError('Mutation audit positive control failed')
        for name, test_filter, mutated in cases:
            (project / ENCODER_KEY).write_text(mutated)
            log = destination / f'{name}.txt'
            code = execute(project, test_filter, log)
            raw = log.read_text()
            if code == 0:
                raise ValueError('Mutant unexpectedly passed: ' + name)
            validate_failure(raw, test_filter)
            results.append({'mutation': name, 'test': test_filter, 'rejected': True,
                'encoder_sha256': hashlib.sha256(mutated.encode()).hexdigest(),
                'report_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
            print('Rejected ' + name + ' through production output comparison', flush=True)
    record = {'schema': 1, 'encoder_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'positive_control_sha256': hashlib.sha256(positive.read_bytes()).hexdigest(), 'mutations': results}
    (destination / 'mutations.json').write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        run(args.output.resolve())
    except (ValueError, OSError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
