#!/usr/bin/env python3
"""Enforce the production offline-only architecture."""

from pathlib import Path
import re
import sys

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

RUNTIME_ROOTS = [ROOT / "lib", ROOT / "android"]

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
        text = path.read_text(errors="ignore")
        for token in BANNED_RUNTIME:
            if token in text:
                fail(f"{token} found in {path.relative_to(ROOT)}")

print("Offline architecture policy: PASS")
