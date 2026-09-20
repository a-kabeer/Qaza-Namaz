#!/usr/bin/env python3
"""Audit Android release signing compatibility.

Usage:
  python tools/android_signing_audit.py --apk build/app/outputs/flutter-apk/app-release.apk
  python tools/android_signing_audit.py --keystore android/release-keystore.jks --alias <alias>

The script never prints passwords or private key material. It reports package ID
and certificate fingerprints so a release artifact can be compared with the
installed/production signing identity.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run(command: list[str], *, env: dict[str, str] | None = None) -> str:
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"Required tool not found: {command[0]}") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout).strip()
        raise SystemExit(f"Command failed: {' '.join(command)}\n{detail}") from exc
    return result.stdout


def normalize_fingerprint(value: str) -> str:
    return re.sub(r"[^0-9A-Fa-f]", "", value).lower()


def apk_audit(apk: Path) -> tuple[str, str, str]:
    apksigner = shutil.which("apksigner")
    if not apksigner:
        raise SystemExit(
            "apksigner was not found. Run this from an Android SDK environment "
            "or provide the APK to Android Studio's APK Analyzer."
        )

    output = run([apksigner, "verify", "--print-certs", str(apk)])
    cert_sha256 = ""
    cert_sha1 = ""
    for line in output.splitlines():
        if "Signer #1 certificate SHA-256 digest:" in line:
            cert_sha256 = normalize_fingerprint(line.split(":", 1)[1])
        elif "Signer #1 certificate SHA-1 digest:" in line:
            cert_sha1 = normalize_fingerprint(line.split(":", 1)[1])

    if not cert_sha256:
        raise SystemExit("Could not extract the APK signing certificate SHA-256.")

    package = "unknown"
    aapt = shutil.which("aapt2") or shutil.which("aapt")
    if aapt:
        badging = run([aapt, "dump", "badging", str(apk)])
        match = re.search(r"package: name='([^']+)'", badging)
        if match:
            package = match.group(1)

    return package, cert_sha1, cert_sha256


def keystore_audit(
    keystore: Path, alias: str, store_password: str, key_password: str | None
) -> tuple[str, str]:
    keytool = shutil.which("keytool")
    if not keytool:
        raise SystemExit("keytool was not found.")

    command = [
        keytool,
        "-list",
        "-v",
        "-keystore",
        str(keystore),
        "-alias",
        alias,
        "-storepass",
        store_password,
    ]
    if key_password:
        command.extend(["-keypass", key_password])

    output = run(command)
    sha1 = ""
    sha256 = ""
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("SHA1:"):
            sha1 = normalize_fingerprint(stripped.split(":", 1)[1])
        elif stripped.startswith("SHA256:"):
            sha256 = normalize_fingerprint(stripped.split(":", 1)[1])

    if not sha256:
        raise SystemExit("Could not extract the keystore SHA-256 certificate.")
    return sha1, sha256


def firebase_sha1s(config_path: Path, package: str) -> list[str]:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    values: list[str] = []
    for client in config.get("client", []):
        info = client.get("client_info", {})
        android = info.get("android_client_info", {})
        if android.get("package_name") != package:
            continue
        for oauth in client.get("oauth_client", []):
            android_info = oauth.get("android_info", {})
            if (
                oauth.get("client_type") == 1
                and android_info.get("package_name") == package
                and android_info.get("certificate_hash")
            ):
                values.append(normalize_fingerprint(android_info["certificate_hash"]))
    return sorted(set(values))


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--apk", type=Path)
    source.add_argument("--keystore", type=Path)
    parser.add_argument("--alias")
    parser.add_argument("--store-password", default="")
    parser.add_argument("--key-password", default=None)
    parser.add_argument(
        "--firebase-config",
        type=Path,
        default=Path("android/app/google-services.json"),
    )
    args = parser.parse_args()

    if args.apk:
        package, sha1, sha256 = apk_audit(args.apk)
        print(f"Package ID: {package}")
        print(f"APK SHA-1: {sha1 or 'unavailable'}")
        print(f"APK SHA-256: {sha256}")

        if args.firebase_config.exists() and package != "unknown":
            registered = firebase_sha1s(args.firebase_config, package)
            print(
                "Firebase SHA-1 match: "
                + ("YES" if sha1 and sha1 in registered else "NO")
            )
            if registered:
                print("Firebase registered SHA-1 count:", len(registered))
        return 0

    if not args.alias:
        raise SystemExit("--alias is required with --keystore.")

    sha1, sha256 = keystore_audit(
        args.keystore, args.alias, args.store_password, args.key_password
    )
    print(f"Keystore SHA-1: {sha1}")
    print(f"Keystore SHA-256: {sha256}")

    if args.firebase_config.exists():
        # The Firebase file does not identify a certificate by keystore; the
        # SHA-1 is the stable cross-check for Google Sign-In configuration.
        packages = json.loads(args.firebase_config.read_text(encoding="utf-8")).get(
            "client", []
        )
        matches = sorted(
            {
                normalize_fingerprint(o["android_info"]["certificate_hash"])
                for client in packages
                for o in client.get("oauth_client", [])
                if o.get("client_type") == 1
                and o.get("android_info", {}).get("certificate_hash")
            }
        )
        print("Firebase SHA-1 match: " + ("YES" if sha1 in matches else "NO"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
