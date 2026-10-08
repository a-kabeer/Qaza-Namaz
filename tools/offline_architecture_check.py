#!/usr/bin/env python3
"""Enforce the production offline-only architecture."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

BANNED_RUNTIME = (
    "firebase_core",
    "firebase_auth",
    "cloud_firestore",
    "google_sign_in",
    "firebase_app_check",
    "connectivity_plus",
    "workmanager",
    "FirebaseServices",
    "GoogleFirebaseAuthService",
    "FirebaseBackup",
    "FirebaseReconciliation",
    "FirebaseAppCheck",
    "FirebaseFirestore",
    "FirebaseAuth",
    "GoogleSignIn",
)

# Generated localization sources may legitimately contain historical
# user-facing provider names. They are not executable online runtime paths.
RUNTIME_ROOTS = [ROOT / "lib", ROOT / "android"]
RUNTIME_EXCLUDED_PARTS = {Path("lib/l10n")}


def fail(message: str) -> None:
    print(f"OFFLINE POLICY ERROR: {message}")
    raise SystemExit(1)


for forbidden in (
    ROOT / "android/app/google-services.json",
    ROOT / "firebase.json",
    ROOT / "firestore.rules",
):
    if forbidden.exists():
        fail(f"cloud configuration still exists: {forbidden.relative_to(ROOT)}")

settings = (ROOT / "android/settings.gradle").read_text()
app_gradle = (ROOT / "android/app/build.gradle").read_text()
manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text()
pubspec = (ROOT / "pubspec.yaml").read_text()

if "com.google.gms.google-services" in settings or "com.google.gms.google-services" in app_gradle:
    fail("Google Services Gradle plugin is still configured")

for package in (
    "firebase_core",
    "firebase_auth",
    "cloud_firestore",
    "google_sign_in",
    "firebase_app_check",
    "connectivity_plus",
    "workmanager",
):
    if re.search(rf"^\s+{re.escape(package)}\s*:", pubspec, re.MULTILINE):
        fail(f"online dependency remains in pubspec.yaml: {package}")

if "android.permission.INTERNET" in manifest:
    fail("INTERNET permission remains in the main Android manifest")

for root in RUNTIME_ROOTS:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in {".dart", ".gradle", ".xml", ".kts"}:
            continue
        relative = path.relative_to(ROOT)
        if any(
            relative == excluded or excluded in relative.parents
            for excluded in RUNTIME_EXCLUDED_PARTS
        ):
            continue
        file_text = path.read_text(errors="ignore")
        for token in BANNED_RUNTIME:
            if token in file_text:
                fail(f"{token} found in {relative}")

print("Offline architecture policy: PASS")
