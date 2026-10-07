#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
TEST = ROOT / "test"

GENERATED_SUFFIXES = (".g.dart", ".freezed.dart")
DEAD_DIAGNOSTIC_CODES = {
    "unused_import",
    "unused_element",
    "unused_local_variable",
    "dead_code",
    "dead_null_aware_expression",
    "unreachable_from_main",
    "unused_catch_clause",
    "unused_shown_name",
    "unused_label",
}

IMPORT_RE = re.compile(
    r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",
    re.MULTILINE,
)
PACKAGE_RE = re.compile(r"""['"]package:([^/]+)/""")
PUB_DEP_RE = re.compile(r"""^  ([A-Za-z0-9_-]+):(?:\s|$)""")


def is_generated(path: Path) -> bool:
    return path.name.endswith(GENERATED_SUFFIXES)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def local_target(source: Path, uri: str) -> Path | None:
    if uri.startswith("package:qaza_namaz/"):
        return LIB / uri.removeprefix("package:qaza_namaz/")
    if uri.startswith("package:") or uri.startswith("dart:") or uri.startswith(
        "flutter:"
    ):
        return None
    return (source.parent / uri).resolve()


def parse_direct_dependencies(pubspec: str) -> tuple[list[str], list[str]]:
    section: str | None = None
    dependencies: list[str] = []
    dev_dependencies: list[str] = []

    for line in pubspec.splitlines():
        if re.match(r"^dependencies:\s*$", line):
            section = "dependencies"
            continue
        if re.match(r"^dev_dependencies:\s*$", line):
            section = "dev_dependencies"
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*$", line):
            section = None

        match = PUB_DEP_RE.match(line)
        if match and section == "dependencies":
            dependencies.append(match.group(1))
        elif match and section == "dev_dependencies":
            dev_dependencies.append(match.group(1))

    return dependencies, dev_dependencies


def package_usage(
    paths: set[Path], texts: dict[Path, str]
) -> dict[str, dict[str, set[Path]]]:
    usage: dict[str, dict[str, set[Path]]] = defaultdict(
        lambda: {"production": set(), "tests": set(), "generated": set()}
    )
    for path in paths:
        kind = (
            "generated"
            if is_generated(path)
            else "production"
            if path.is_relative_to(LIB)
            else "tests"
        )
        for package in PACKAGE_RE.findall(texts[path]):
            usage[package][kind].add(path)
    return usage


def extract_analyzer_diagnostics(path: Path | None) -> list[str]:
    if path is None:
        return []

    output = read_text(path)
    diagnostics: list[str] = []
    for line in output.splitlines():
        normalized = line.casefold()
        if any(
            re.search(rf"\b{re.escape(code)}\b", normalized)
            for code in DEAD_DIAGNOSTIC_CODES
        ):
            diagnostics.append(line)
    return diagnostics


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Static dead-code and dependency audit. Analyzer output is supplied "
            "by the existing CI analyzer step."
        )
    )
    parser.add_argument(
        "--analyzer-output",
        type=Path,
        help="Path to the machine-readable flutter analyze output.",
    )
    args = parser.parse_args()

    dart_files = {
        path for root in (LIB, TEST) for path in root.rglob("*.dart")
    }
    texts = {path: read_text(path) for path in dart_files}

    lib_files = {path for path in dart_files if path.is_relative_to(LIB)}
    source_files = {path for path in lib_files if not is_generated(path)}
    test_files = {
        path
        for path in dart_files
        if path.is_relative_to(TEST) and not is_generated(path)
    }

    graph: dict[Path, set[Path]] = defaultdict(set)
    for source, text in texts.items():
        for uri in IMPORT_RE.findall(text):
            target = local_target(source, uri)
            if target is None:
                continue
            if target.exists() and target.suffix == ".dart":
                graph[source].add(target)
            else:
                candidate = target.with_suffix(".dart")
                if candidate.exists():
                    graph[source].add(candidate)

    def reachable_from(root: Path) -> set[Path]:
        seen: set[Path] = set()
        stack = [root]
        while stack:
            current = stack.pop()
            if current in seen:
                continue
            seen.add(current)
            stack.extend(graph.get(current, ()))
        return seen

    prod_root = LIB / "main.dart"
    prod_reachable = reachable_from(prod_root) if prod_root.exists() else set()

    test_reachable: set[Path] = set()
    for test_file in test_files:
        test_reachable.update(reachable_from(test_file))

    production_unreachable = sorted(source_files - prod_reachable)
    test_only_reachable = sorted(
        path for path in production_unreachable if path in test_reachable
    )
    unreferenced_sources = sorted(
        path for path in production_unreachable if path not in test_reachable
    )

    orphan_tests = sorted(
        path
        for path in test_files
        if not any(
            target in lib_files or target.is_relative_to(LIB)
            for target in graph.get(path, ())
        )
    )

    dependencies, dev_dependencies = parse_direct_dependencies(
        read_text(ROOT / "pubspec.yaml")
    )
    usage = package_usage(dart_files, texts)

    unused_dependencies: list[str] = []
    test_only_dependencies: list[str] = []
    generated_only_dependencies: list[str] = []

    for package in dependencies:
        package_usage_info = usage.get(
            package,
            {"production": set(), "tests": set(), "generated": set()},
        )
        production = package_usage_info["production"]
        tests = package_usage_info["tests"]
        generated = package_usage_info["generated"]

        if production:
            continue
        if generated:
            generated_only_dependencies.append(package)
        elif tests:
            test_only_dependencies.append(package)
        else:
            unused_dependencies.append(package)

    analyzer_diagnostics = extract_analyzer_diagnostics(args.analyzer_output)

    print("=== DEAD CODE AUDIT ===")
    print(f"lib_files={len(lib_files)}")
    print(f"test_files={len(test_files)}")
    print(f"production_reachable={len(prod_reachable)}")
    print(f"production_unreachable={len(production_unreachable)}")
    print(f"production_unreachable_test_reachable={len(test_only_reachable)}")
    print(f"production_unreachable_unreferenced={len(unreferenced_sources)}")
    print(f"orphan_tests={len(orphan_tests)}")
    print(f"unused_direct_dependencies={len(unused_dependencies)}")
    print(f"test_only_direct_dependencies={len(test_only_dependencies)}")
    print(f"generated_only_direct_dependencies={len(generated_only_dependencies)}")
    print(f"analyzer_unused_dead_diagnostics={len(analyzer_diagnostics)}")
    print(f"direct_dependencies={len(dependencies)}")
    print(f"direct_dev_dependencies={len(dev_dependencies)}")
    print()

    print("[UNUSED DIRECT DEPENDENCIES]")
    for package in unused_dependencies:
        print(package)
    print()

    print("[TEST-ONLY DIRECT DEPENDENCIES]")
    for package in test_only_dependencies:
        print(package)
    print()

    print("[GENERATED-ONLY DIRECT DEPENDENCIES]")
    for package in generated_only_dependencies:
        print(package)
    print()

    print("[PRODUCTION-UNREACHABLE LIB FILES]")
    for path in production_unreachable:
        print(path.relative_to(ROOT))
    print()

    print("[PRODUCTION-UNREACHABLE BUT TEST-REACHABLE]")
    for path in test_only_reachable:
        print(path.relative_to(ROOT))
    print()

    print("[PRODUCTION-UNREACHABLE AND UNREFERENCED]")
    for path in unreferenced_sources:
        print(path.relative_to(ROOT))
    print()

    print("[TESTS WITH NO APPLICATION SOURCE IMPORT]")
    for path in orphan_tests:
        print(path.relative_to(ROOT))
    print()

    print("[DART ANALYZER UNUSED/DEAD DIAGNOSTICS]")
    for line in analyzer_diagnostics:
        print(line)
    print()

    print(
        "ANALYZER_OUTPUT="
        + ("not_supplied" if args.analyzer_output is None else str(args.analyzer_output))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
