#!/usr/bin/env python3
"""Assert the POC manifest's deliberately exact direct package versions."""

from pathlib import Path
import re
import sys

EXPECTED = {
    "powersync": "2.5.0",
    "sqlite_async": "0.14.5",
    "drift_sqlite_async": "0.3.1",
    "drift": "2.35.0",
    "sqlite3": "3.6.0",
    "supabase_flutter": "2.18.3",
    "flutter_lints": "6.0.0",
}


def main() -> int:
    lock_path = Path("pubspec.lock")
    if not lock_path.is_file():
        print("ERROR: pubspec.lock has not been generated.", file=sys.stderr)
        return 2

    text = lock_path.read_text(encoding="utf-8")
    failures = []
    for name, expected in EXPECTED.items():
        match = re.search(
            rf"(?ms)^  {re.escape(name)}:\n(.*?)(?=^  [A-Za-z0-9_][A-Za-z0-9_-]*:\n|\Z)",
            text,
        )
        if not match:
            failures.append(f"{name}: missing from pubspec.lock (expected {expected})")
            continue
        version_match = re.search(r'^    version:\s*["\']?([^"\'\r\n]+)', match.group(1), re.MULTILINE)
        if not version_match:
            failures.append(f"{name}: version field missing (expected {expected})")
            continue
        actual = version_match.group(1).strip()
        if actual != expected:
            failures.append(f"{name}: expected {expected}, got {actual}")
        else:
            print(f"PIN OK: {name} {actual}")

    if failures:
        for failure in failures:
            print(f"PIN ERROR: {failure}", file=sys.stderr)
        return 1
    print(f"Exact direct dependency pins verified: {len(EXPECTED)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
