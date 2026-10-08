#!/usr/bin/env python3
"""Enforce the one-way Phase 1 -> Phase 2 dependency boundary.

Phase 1 is the shippable offline application. Any future cloud/Google Drive
adapter may depend on Phase 1 contracts, but Phase 1 source must never import
Phase 2/cloud/authentication code.
"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
PUBSPEC = ROOT / "pubspec.yaml"

IMPORT_PATTERN = re.compile(
    r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",
    re.MULTILINE,
)

FORBIDDEN_REFERENCE = re.compile(
    r"""(?:^|[/._-])(phase[_-]?2|qaza[_-]?cloud|cloud[_-]?adapter|google[_-]?(?:drive|sign[W_]*in)|firebase)(?:[/._-]|$)""",
    re.IGNORECASE,
)

FORBIDDEN_IMPORT_PATHS = (
    "package:firebase_",
    "package:cloud_firestore",
    "package:google_sign_in",
    "package:googleapis",
    "package:qaza_cloud",
    "package:cloud_adapter",
)


def fail(message: str) -> None:
    print(f"PHASE BOUNDARY ERROR: {message}")
    raise SystemExit(1)


if not LIB.exists():
    fail("lib/ is missing")

if not PUBSPEC.exists():
    fail("pubspec.yaml is missing")

for path in LIB.rglob("*.dart"):
    text = path.read_text(errors="ignore")
    for match in IMPORT_PATTERN.finditer(text):
        target = match.group(1)
        normalized = target.lower()
        if any(token in normalized for token in FORBIDDEN_IMPORT_PATHS):
            fail(f"Phase 1 source imports forbidden Phase 2/cloud path: {path} -> {target}")
        if FORBIDDEN_REFERENCE.search(normalized):
            fail(f"Phase 1 source has a forbidden Phase 2/cloud import reference: {path} -> {target}")

pubspec = PUBSPEC.read_text(errors="ignore").lower()
for token in (
    "qaza_cloud",
    "cloud_adapter",
    "phase2",
    "googleapis",
    "google_sign_in",
    "firebase_core",
    "firebase_auth",
    "cloud_firestore",
):
    if re.search(rf"^\s+{re.escape(token)}\s*:", pubspec, re.MULTILINE):
        fail(f"Phase 2/cloud dependency appears in pubspec.yaml: {token}")

print("Phase 1 -> Phase 2 dependency boundary: PASS")
