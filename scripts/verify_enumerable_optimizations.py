#!/usr/bin/env python3
"""Check skipped-write/read assumptions. Run only in an isolated, idle worktree.

Each optimization is temporarily disabled separately and all are disabled together;
the same state/invariant suite must still pass. Unsafe variants must compile cleanly
and fail at least two runtime cases. Source files are restored in finally.
"""
import argparse
import hashlib
from itertools import permutations
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOKEN = ROOT / "packages/embeddable_game_standard/src/token"
COMPONENT = TOKEN / "extensions/enumerable/enumerable.cairo"
FIXTURES = TOKEN / "tests/enumerable_fixtures.cairo"
TESTS = TOKEN / "tests/test_enumerable_optimizations.cairo"
OPTIMIZATIONS = ("first_mint", "transfer_clear", "burn_zero_clear", "storage_entries", "shared_owner")


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise RuntimeError(f"Expected exactly one source match: {before}")
    return text.replace(before, after)


def without_optimizations(original, disabled):
    component, fixture = original[COMPONENT], original[FIXTURES]
    if "first_mint" in disabled:
        component = replace_once(component,
            "if !is_mint || len != 0 {\n                self.Enumerable_owned_tokens_index.write(token_id, len);\n            }",
            "self.Enumerable_owned_tokens_index.write(token_id, len);")
    clear = "if is_burn && this_token_index != 0 {\n                index_entry.write(0);\n            }"
    if {"transfer_clear", "burn_zero_clear"} <= disabled:
        component = replace_once(component, clear, "index_entry.write(0);")
    elif "transfer_clear" in disabled:
        component = replace_once(component, "if is_burn && this_token_index != 0 {", "if !is_burn || this_token_index != 0 {")
    elif "burn_zero_clear" in disabled:
        component = replace_once(component, "if is_burn && this_token_index != 0 {", "if is_burn {")
    if "storage_entries" in disabled:
        for before, after in (
            ("            let index_entry = self.Enumerable_owned_tokens_index.entry(token_id);\n", ""),
            ("            let last_entry = self.Enumerable_owned_tokens.entry((from, last_token_index));\n", ""),
            ("index_entry.read()", "self.Enumerable_owned_tokens_index.read(token_id)"),
            ("last_entry.read()", "self.Enumerable_owned_tokens.read((from, last_token_index))"),
            ("last_entry.write(0)", "self.Enumerable_owned_tokens.write((from, last_token_index), 0)"),
            ("index_entry.write(0)", "self.Enumerable_owned_tokens_index.write(token_id, 0)"),
            ("        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,\n        StoragePointerReadAccess, StoragePointerWriteAccess,", "        Map, StorageMapReadAccess, StorageMapWriteAccess,"),
        ):
            component = replace_once(component, before, after)
    if "shared_owner" in disabled:
        fixture = replace_once(fixture,
            "let id = token_id.try_into().expect(EnumerableComponent::Errors::TOKEN_ID_OUT_OF_RANGE);",
            "let id: felt252 = token_id.try_into().expect(EnumerableComponent::Errors::TOKEN_ID_OUT_OF_RANGE);")
        fixture = replace_once(fixture,
            "contract.enumerable.before_update_with_owner(to, id, previous_owner);",
            "contract.enumerable.before_update(to, id.into());")
    return {COMPONENT: component, FIXTURES: fixture}


def check_matrix():
    def encode(items):
        return sum((token + 1) * 4**index for index, token in enumerate(items))
    states = set()
    for length in range(4):
        for order in permutations(range(3), length):
            for cut in range(length + 1):
                states.add((order[:cut], order[cut:]))
    expected = {(encode(a), encode(b)) for a, b in states}
    cases = [tuple(map(int, pair)) for pair in re.findall(r"#\[test_case\((\d+), (\d+)\)\]", TESTS.read_text())]
    assert len(cases) == len(set(cases)) == len(expected) == 49
    assert set(cases) == expected
    assert sum(6 + len(a) + len(b) for a, b in states) == 408


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    directory = parser.parse_args().output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    check_matrix()
    original = {path: path.read_text() for path in (COMPONENT, FIXTURES)}
    variants = [("original", original, True)]
    variants += [(f"without_{name}", without_optimizations(original, {name}), True) for name in OPTIMIZATIONS]
    variants.append(("without_all", without_optimizations(original, set(OPTIMIZATIONS)), True))
    for name, path, before, after in (
        ("skip_all_mint_reverse_writes", COMPONENT, "if !is_mint || len != 0 {", "if !is_mint {"),
        ("skip_zero_transfer_destination", COMPONENT, "if !is_mint || len != 0 {", "if len != 0 {"),
        ("retain_nonzero_burn_reverse", COMPONENT, "if is_burn && this_token_index != 0 {", "if is_burn && this_token_index == 0 {"),
        ("wrong_cached_entry_key", COMPONENT, "self.Enumerable_owned_tokens_index.entry(token_id)", "self.Enumerable_owned_tokens_index.entry(last_token_index)"),
        ("use_authorizer_as_owner", FIXTURES,
            "contract.enumerable.before_update_with_owner(to, id, previous_owner);",
            "contract.enumerable.before_update_with_owner(to, id, if previous_owner.is_zero() { previous_owner } else { auth });"),
    ):
        mutated = dict(original)
        mutated[path] = replace_once(mutated[path], before, after)
        variants.append((name, mutated, False))
    results = []
    try:
        for name, sources, must_pass in variants:
            for path, source in sources.items():
                path.write_text(source)
            log = directory / f"{name}.log"
            env = os.environ.copy()
            env["SCARB_PROFILE"] = "dev"
            with log.open("w") as output:
                result = subprocess.run([
                    "snforge", "test", "-p", "game_components_embeddable_game_standard",
                    "::test_enumerable_optimizations::", "--color", "never",
                ], cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
            text = log.read_text()
            if re.search(r"^\s*(?:warn|warning|error)(?:\[|:)", text, re.M | re.I):
                raise RuntimeError(f"Compilation diagnostic: {log}")
            passed = re.findall(r"^\[PASS\] (\S+)", text, re.M)
            failed = re.findall(r"^\[FAIL\] (\S+)", text, re.M)
            if must_pass:
                assert result.returncode == 0 and len(passed) == 53 and not failed, log
            else:
                assert result.returncode == 1 and len(failed) >= 2, log
                assert "RunResources has no remaining steps" not in text, log
            results.append(dict(name=name, expected_pass=must_pass, passed=len(passed), failed=failed))
            print(f"{name}: {len(passed)} pass, {len(failed)} runtime failures", flush=True)
    finally:
        for path, source in original.items():
            path.write_text(source)
    for path, source in original.items():
        assert path.read_text() == source
    report = dict(
        state_matrix=dict(states=49, transitions_per_hook=408, hook_variants=2),
        results=results,
        source_sha256={str(path.relative_to(ROOT)): hashlib.sha256(source.encode()).hexdigest() for path, source in original.items()},
    )
    (directory / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    print("All optimization checks passed; source restored.")


if __name__ == "__main__":
    main()
