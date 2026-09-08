#!/usr/bin/env python3
"""Reproduce Enumerable Lite execution measurements twice on the pinned toolchain."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "game_components_embeddable_game_standard"
CASES = (
    "mint_first", "mint_repeat", "transfer_last", "transfer_middle", "transfer_self",
    "burn_last", "burn_middle",
)
EXPECTED = {
    f"{variant}_{case}"
    for variant in ("reference", "optimized", "generic")
    for case in CASES
    if variant != "reference" or not case.startswith("burn_")
}
CONTRACTS = ("EnumerableReferenceMock", "EnumerableOwnerMock", "EnumerableGenericMock")


def run(command, log, profile="dev"):
    env = os.environ.copy()
    env["SCARB_PROFILE"] = profile
    with log.open("w") as output:
        subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, check=True)
    text = log.read_text()
    if re.search(r"^warn(?:\[|:|ing:)", text, re.MULTILINE | re.IGNORECASE):
        raise RuntimeError(f"Compiler warning in {log}")
    return text


def parse(text):
    rows = {}
    current = None
    probe = False
    for line in text.splitlines():
        match = re.match(r"\[PASS\].*::enumgas_(\w+) \(", line)
        if match:
            current = match[1]
            if current in rows:
                raise ValueError(f"Duplicate test: {current}")
            rows[current] = {}
            probe = False
        elif re.match(r"\| \w+ Contract\s*\|", line):
            probe = "EnumerationGasProbe Contract" in line
        elif current and probe:
            columns = [part.strip() for part in line.split("|")]
            if len(columns) == 8 and columns[1] in ("measure", "floor"):
                minimum, maximum, average, deviation, calls = map(int, columns[2:7])
                if not (minimum == maximum == average and deviation == 0 and calls == 1):
                    raise ValueError(f"Non-isolated measurement: {current}: {line}")
                key = "raw" if columns[1] == "measure" else "floor"
                if key in rows[current]:
                    raise ValueError(f"Duplicate measurement: {current}: {key}")
                rows[current][key] = minimum
    if set(rows) != EXPECTED:
        raise ValueError(f"Unexpected cases: missing={EXPECTED - set(rows)}, extra={set(rows) - EXPECTED}")
    for case, row in rows.items():
        if set(row) != {"raw", "floor"}:
            raise ValueError(f"Incomplete row: {case}")
        row["adjusted"] = row["raw"] - row["floor"]
        if row["adjusted"] <= 0:
            raise ValueError(f"Invalid floor: {case}")
    return rows


def sizes(directory):
    result = {}
    for profile in ("dev", "release"):
        run(["scarb", "build", "--test", "-p", PACKAGE], directory / f"build-{profile}.log", profile)
        result[profile] = {}
        for name in CONTRACTS:
            sierra = ROOT / "target" / profile / f"{PACKAGE}_unittest_{name}.test.contract_class.json"
            casm = directory / f"{profile}-{name}.casm.json"
            run([
                "universal-sierra-compiler", "compile-contract", "--sierra-path", str(sierra),
                "--output-path", str(casm),
            ], directory / f"{profile}-{name}-compile.log")
            result[profile][name] = {
                "sierra_felts": len(json.loads(sierra.read_text())["sierra_program"]),
                "casm_felts": len(json.loads(casm.read_text())["bytecode"]),
            }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Directory for logs and reports")
    args = parser.parse_args()
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    versions = {
        tool: subprocess.check_output([tool, "--version"], cwd=ROOT, text=True).strip()
        for tool in ("scarb", "snforge", "universal-sierra-compiler")
    }
    command = [
        "snforge", "test", "-p", PACKAGE, "enumgas_", "--ignored", "--gas-report",
        "--tracked-resource", "sierra-gas", "--detailed-resources", "--color", "never",
    ]
    runs = []
    for number in (1, 2):
        print(f"Measuring run {number}/2", flush=True)
        runs.append(parse(run(command, directory / f"run-{number}.log")))
    if runs[0] != runs[1]:
        raise RuntimeError("Measurements did not reproduce exactly")
    rows = runs[0]
    for case in CASES[:5]:
        before, after = rows[f"reference_{case}"], rows[f"optimized_{case}"]
        if before["floor"] != after["floor"]:
            raise RuntimeError(f"Unmatched ABI floor: {case}")
        if after["raw"] >= before["raw"]:
            raise RuntimeError(f"No optimization saving: {case}")
    print("Measuring dev/release fixture sizes", flush=True)
    compiled_sizes = sizes(directory)
    sources = [ROOT / "Scarb.toml", ROOT / "Scarb.lock", ROOT / ".tool-versions"]
    sources += sorted((ROOT / "packages/embeddable_game_standard/src/token").rglob("*.cairo"))
    report = {
        "versions": versions,
        "profile": "dev (repository defaults, including inlining-strategy=avoid)",
        "resource": "Sierra execution gas; not transaction fees or storage data gas",
        "boundary": "One forwarding probe call; adjusted subtracts only the outer ABI no-op floor, retaining CallContract overhead",
        "reference_commit": "17558e939ab807776c785181551b5737699d443f",
        "exact_agreement": True,
        "measurements": rows,
        "sizes": compiled_sizes,
        "source_sha256": {
            str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources
        },
    }
    (directory / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = [
        "# Enumerable Lite execution benchmark", "",
        "Both runs agree exactly. Reference and optimized fixtures share the same soulbound rule; "
        "the optimized hook reuses its owner read. The generic fixture has no soulbound guard.", "",
        "Raw includes forwarding/ABI costs; adjusted subtracts the outer ABI floor only. "
        "These are execution measurements, not transaction fees or a mainnet price quote.", "",
        "| Operation | Reference raw | Optimized raw | Floor | Reference adjusted | Optimized adjusted | Saving |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case in CASES:
        after = rows[f"optimized_{case}"]
        before = rows.get(f"reference_{case}")
        if before:
            lines.append(
                f"| {case} | {before['raw']:,} | {after['raw']:,} | {after['floor']:,} | "
                f"{before['adjusted']:,} | {after['adjusted']:,} | {before['raw'] - after['raw']:,} |"
            )
        else:
            lines.append(f"| {case} | unsupported | {after['raw']:,} | {after['floor']:,} | — | {after['adjusted']:,} | — |")
    lines += ["", "## Fixture sizes", "", "| Profile / fixture | Sierra felts | CASM felts |", "| --- | ---: | ---: |"]
    for profile, contracts in compiled_sizes.items():
        for name, size in contracts.items():
            lines.append(f"| {profile} / {name} | {size['sierra_felts']:,} | {size['casm_felts']:,} |")
    (directory / "comparison.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"Reports and source hashes: {directory}")


if __name__ == "__main__":
    main()
