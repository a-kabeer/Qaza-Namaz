#!/usr/bin/env python3
"""Create a conservative license-file inventory from Dart's package config.

This is a triage report, not a license-compliance verdict. Unknown or missing
licenses are explicitly flagged for human review.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlparse

LICENSE_FILENAME = re.compile(
    r"^(?:LICENSE|LICENCE|COPYING|NOTICE|COPYRIGHT|PATENTS)(?:[._-].*)?$",
    re.IGNORECASE,
)
VERSION_SUFFIX = re.compile(r"-(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)$")
SPDX_PATTERN = re.compile(r"SPDX-License-Identifier:\s*([^\r\n*]+)", re.IGNORECASE)


def resolve_root(config_path: Path, root_uri: str) -> Path:
    parsed = urlparse(root_uri)
    if parsed.scheme == "file":
        return Path(unquote(parsed.path)).resolve()
    if parsed.scheme:
        return Path()
    return (config_path.parent / unquote(root_uri)).resolve()


def license_files(package_root: Path) -> list[Path]:
    if not package_root.is_dir():
        return []
    try:
        return sorted(
            (
                path
                for path in package_root.iterdir()
                if path.is_file() and LICENSE_FILENAME.match(path.name)
            ),
            key=lambda path: path.name.casefold(),
        )
    except OSError:
        return []


def classify_license(paths: list[Path]) -> tuple[str, str]:
    """Return a conservative marker and status; never infer from package name."""
    if not paths:
        return "NO LICENSE FILE FOUND", "MANUAL REVIEW REQUIRED"

    detected: list[str] = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")[:100_000]
        except OSError:
            continue

        spdx = [
            value.strip().strip("*/ ")
            for value in SPDX_PATTERN.findall(text)
            if value.strip()
        ]
        for value in spdx:
            if value not in detected:
                detected.append(value)
        if spdx:
            continue

        lower = text.lower()
        marker = None
        if "apache license" in lower and "version 2.0" in lower:
            marker = "Apache-2.0 (text marker)"
        elif "mozilla public license version 2.0" in lower:
            marker = "MPL-2.0 (text marker)"
        elif "isc license" in lower or (
            "permission to use, copy, modify, and/or distribute this software"
            in lower
        ):
            marker = "ISC (text marker)"
        elif "the unlicense" in lower:
            marker = "Unlicense (text marker)"
        elif "mit license" in lower or (
            "permission is hereby granted, free of charge, to any person obtaining a copy"
            in lower
        ):
            marker = "MIT (text marker)"
        elif (
            "redistribution and use in source and binary forms" in lower
            and "neither the name of" in lower
            and "endorse or promote products derived from this software" in lower
        ):
            marker = "BSD-3-Clause (text marker)"
        elif (
            "redistribution and use in source and binary forms" in lower
            and "neither the name of" not in lower
        ):
            marker = "BSD-2-Clause (text marker)"
        elif "zlib license" in lower or "this software is provided 'as-is'" in lower:
            marker = "Zlib (text marker)"

        if marker and marker not in detected:
            detected.append(marker)

    if not detected:
        return "License file present; type not confidently detected", "MANUAL REVIEW REQUIRED"
    return "; ".join(detected), "REVIEW LICENSE TEXT"


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(".dart_tool/package_config.json"),
        help="Path to the Dart package_config.json file",
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output Markdown report path",
    )
    args = parser.parse_args()

    if not args.config.is_file():
        parser.error(f"package config not found: {args.config}")

    config = json.loads(args.config.read_text(encoding="utf-8"))
    entries = config.get("packages", [])
    rows: list[tuple[str, str, str, str, str]] = []
    for entry in entries:
        name = str(entry.get("name", ""))
        if name == "qaza_supabase_powersync_poc":
            continue
        package_root = resolve_root(args.config.resolve(), str(entry.get("rootUri", "")))
        version_match = VERSION_SUFFIX.search(package_root.name)
        version = version_match.group(1) if version_match else "version not inferred"
        files = license_files(package_root)
        license_type, status = classify_license(files)
        file_names = ", ".join(str(p.relative_to(package_root)) for p in files) or "—"
        rows.append((name, version, file_names, license_type, status))

    rows.sort(key=lambda row: row[0].casefold())
    missing = sum(1 for row in rows if row[4] == "MANUAL REVIEW REQUIRED")
    review = sum(1 for row in rows if row[4] == "REVIEW LICENSE TEXT")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Dart dependency license-file inventory",
        "",
        f"- Generated: {generated}",
        f"- Resolved package entries reviewed: {len(rows)}",
        f"- Missing/unclassified files: {missing}",
        f"- License text detected and still needs human inspection: {review}",
        "",
        "> This report only detects license files and conservative text markers. It is not legal advice or an automated approval. Read the actual license text and check every direct/transitive dependency before production use.",
        "",
        "| Package | Version inferred from cache path | License file(s) | Detected marker | Status |",
        "|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append("| " + " | ".join(markdown_cell(item) for item in row) + " |")
    lines.extend(
        [
            "",
            "## Service-level terms (not represented by pub package files)",
            "",
            "- PowerSync client SDKs are Apache-2.0; the self-hosted PowerSync Open Edition service is under the Functional Source License (FSL).",
            "- PowerSync Cloud/Enterprise offerings have separate commercial terms.",
            "- Supabase self-hosted service terms/licenses must be reviewed per component.",
            "- See LICENSE-REVIEW.md and the official sources linked there.",
            "",
        ]
    )
    report = "\n".join(lines)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")
    print(report)
    print(f"\nLicense inventory summary: packages={len(rows)}, missing/unclassified={missing}, human-review={review}")
    # The report deliberately doesn't fail CI on a text-marker miss. The final
    # POC-0 gate remains open until those items are manually reviewed.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
