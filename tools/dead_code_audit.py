#!/usr/bin/env python3
from __future__ import annotations
import re
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
TEST = ROOT / "test"
DART_FILES = sorted([*LIB.rglob("*.dart"), *TEST.rglob("*.dart")])
IMPORT_RE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.MULTILINE)
PACKAGE_RE = re.compile(r"""['"]package:([^/]+)/""")
PUB_DEP_RE = re.compile(r"""^  ([a-zA-Z0-9_]+):(?:\s|$)""")

def read_text(p: Path) -> str:
    try: return p.read_text(encoding="utf-8")
    except UnicodeDecodeError: return ""

def local_target(source: Path, uri: str) -> Path | None:
    if uri.startswith("package:qaza_namaz/"):
        return LIB / uri.removeprefix("package:qaza_namaz/")
    if uri.startswith(("package:", "dart:", "flutter:")):
        return None
    return (source.parent / uri).resolve()

texts = {p: read_text(p) for p in DART_FILES}
lib_set = set(LIB.rglob("*.dart"))
test_set = set(TEST.rglob("*.dart"))
graph = defaultdict(set)

for source, text in texts.items():
    for uri in IMPORT_RE.findall(text):
        target = local_target(source, uri)
        if target is None: continue
        if target.exists() and target.suffix == ".dart":
            graph[source].add(target)
        elif target.with_suffix(".dart").exists():
            graph[source].add(target.with_suffix(".dart"))

seen = set()
stack = [LIB / "main.dart"]
while stack:
    p = stack.pop()
    if p in seen: continue
    seen.add(p)
    stack.extend(graph.get(p, ()))

pubspec = read_text(ROOT / "pubspec.yaml")
section = None
deps, dev_deps = [], []
for line in pubspec.splitlines():
    if re.match(r"^dependencies:\s*$", line): section = "deps"; continue
    if re.match(r"^dev_dependencies:\s*$", line): section = "dev"; continue
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*$", line): section = None
    m = PUB_DEP_RE.match(line)
    if m and section in ("deps", "dev"):
        (deps if section == "deps" else dev_deps).append(m.group(1))

usage = defaultdict(set)
for p, text in texts.items():
    for pkg in PACKAGE_RE.findall(text):
        usage[pkg].add(p)

unused_deps = [p for p in deps if not usage.get(p)]
test_only_deps = [p for p in deps if usage.get(p) and all(x in test_set for x in usage[p])]
unreachable = sorted(lib_set - seen)
test_only_lib = sorted([p for p in unreachable if any(p in graph.get(t, set()) for t in test_set)])
orphan_tests = sorted([t for t in test_set if not any(x in lib_set for x in graph.get(t, set()))])

an = subprocess.run(["dart","analyze","--format","machine"], cwd=ROOT, text=True, capture_output=True)
interesting = []
for line in an.stdout.splitlines():
    if any(f"|{code}|" in line for code in [
        "unused_import","unused_element","unused_local_variable","dead_code",
        "dead_null_aware_expression","unnecessary_import","unused_shown_name",
        "unused_catch_clause","unused_label","empty_statements"]):
        interesting.append(line)

print("=== DEAD CODE AUDIT ===")
print(f"lib_files={len(lib_set)} test_files={len(test_set)} production_reachable={len(seen)}")
print(f"production_unreachable={len(unreachable)} test_only_unreachable={len(test_only_lib)} orphan_tests={len(orphan_tests)}")
print(f"unused_direct_dependencies={len(unused_deps)} test_only_direct_dependencies={len(test_only_deps)}")
print("\n[UNUSED DIRECT DEPENDENCIES]")
print("\n".join(unused_deps) or "(none)")
print("\n[TEST-ONLY DIRECT DEPENDENCIES]")
print("\n".join(test_only_deps) or "(none)")
print("\n[PRODUCTION-UNREACHABLE LIB FILES]")
print("\n".join(str(x.relative_to(ROOT)) for x in unreachable) or "(none)")
print("\n[TEST-ONLY UNREACHABLE LIB FILES]")
print("\n".join(str(x.relative_to(ROOT)) for x in test_only_lib) or "(none)")
print("\n[ORPHAN TEST FILES]")
print("\n".join(str(x.relative_to(ROOT)) for x in orphan_tests) or "(none)")
print("\n[DART ANALYZER UNUSED/DEAD DIAGNOSTICS]")
print("\n".join(interesting) or "(none)")
print(f"ANALYZER_EXIT_CODE={an.returncode}")
