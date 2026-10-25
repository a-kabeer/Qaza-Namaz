#!/usr/bin/env python3
"""Inventory the resolved Dart package license files for POC-0.

The output is a review aid, not a license-compliance verdict. It copies source
license texts into the evidence directory so unknown markers can be reviewed.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
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
        files = sorted(
            (
                path
                for path in package_root.iterdir()
                if path.is_file() and LICENSE_FILENAME.match(path.name)
            ),
            key=lambda path: path.name.casefold(),
        )
    except OSError:
        files = []

    if files:
        return files

    # Flutter SDK packages can inherit the SDK's BSD license at the SDK root.
    for parent in package_root.parents:
        if (parent / "bin" / "flutter").is_file() and (parent / "LICENSE").is_file():
            return [parent / "LICENSE"]
    return []


def classify_license(paths: list[Path]) -> tuple[str, str]:
    """Use explicit SPDX or conservative normalized-text markers only."""
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

        normalized = re.sub(r"\s+", " ", text.lower())
        marker = None
        if "apache-2.0" in normalized or (
            "apache license" in normalized and "version 2.0" in normalized
        ):
            marker = "Apache-2.0 (text marker)"
        elif "mozilla public license version 2.0" in normalized:
            marker = "MPL-2.0 (text marker)"
        elif "isc license" in normalized or (
            "permission to use, copy, modify, and/or distribute this software"
            in normalized
        ):
            marker = "ISC (text marker)"
        elif "the unlicense" in normalized:
            marker = "Unlicense (text marker)"
        elif "mit license" in normalized or (
            "permission is hereby granted, free of charge, to any person obtaining a copy"
            in normalized
        ):
            marker = "MIT (text marker)"
        elif (
            "bsd 3-clause" in normalized
            or "bsd-3-clause" in normalized
            or (
                "redistribution and use in source and binary forms" in normalized
                and "following conditions are met" in normalized
                and ("neither the name of" in normalized or "endorse or promote" in normalized)
            )
        ):
            marker = "BSD-3-Clause (text marker)"
        elif (
            "bsd 2-clause" in normalized
            or "bsd-2-clause" in normalized
            or (
                "redistribution and use in source and binary forms" in normalized
                and "following conditions are met" in normalized
                and "neither the name of" not in normalized
            )
        ):
            marker = "BSD-2-Clause (text marker)"
        elif "zlib license" in normalized or "this software is provided 'as-is'" in normalized:
            marker = "Zlib (text marker)"

        if marker and marker not in detected:
            detected.append(marker)

    if not detected:
        return "License file present; type not confidently detected", "MANUAL REVIEW REQUIRED"
    return "; ".join(detected), "LICENSE MARKER DETECTED — HUMAN REVIEW REQUIRED"


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value)


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

    config_path = args.config.resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    output_path = args.output.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    copied_dir = output_path.parent / "license-texts"
    copied_dir.mkdir(parents=True, exist_ok=True)

    rows: list[tuple[str, str, str, str, str]] = []
    entries = config.get("packages", [])
    for entry in entries:
        name = str(entry.get("name", ""))
        if name == "qaza_supabase_powersync_poc":
            continue

        package_root = resolve_root(config_path, str(entry.get("rootUri", "")))
        version_match = VERSION_SUFFIX.search(package_root.name)
        version = version_match.group(1) if version_match else "version not inferred"
        files = license_files(package_root)
        license_type, status = classify_license(files)
        artifact_names: list[str] = []
        for index, source in enumerate(files, start=1):
            suffix = safe_filename(source.name)
            dest_name = safe_filename(f"{name}-{version}-{index}-{suffix}")
            destination = copied_dir / dest_name
            try:
                shutil.copyfile(source, destination)
                artifact_names.append(f"license-texts/{dest_name}")
            except OSError:
                artifact_names.append(f"COPY FAILED: {source.name}")

        rows.append(
            (
                name,
                version,
                ", ".join(artifact_names) or "—",
                license_type,
                status,
            )
        )

    rows.sort(key=lambda row: row[0].casefold())
    missing = sum(1 for row in rows if row[4] == "MANUAL REVIEW REQUIRED")
    detected = sum(1 for row in rows if row[4] != "MANUAL REVIEW REQUIRED")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Dart dependency license-file inventory",
        "",
        f"- Generated: {generated}",
        f"- Resolved package entries reviewed: {len(rows)}",
        f"- Missing/unclassified files: {missing}",
        f"- Packages with a detected license marker: {detected}",
        "",
        "> The marker detector is conservative and may miss valid licenses. Each source license text is copied into the adjacent license-texts directory for manual inspection. This report is not legal advice or automated compliance approval.",
        "",
        "| Package | Version inferred from cache path | Copied license file(s) | Detected marker | Review status |",
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
            "- Direct package and service sources are linked in LICENSE-REVIEW.md.",
            "",
        ]
    )
    report = "\n".join(lines)
    output_path.write_text(report, encoding="utf-8")
    print(report)
    print(
        f"License inventory summary: packages={len(rows)}, "
        f"missing/unclassified={missing}, detected-markers={detected}"
    )
    # Do not guess or fail solely on classifier uncertainty; the report carries
    # the source texts and the human license review remains an explicit gate.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
