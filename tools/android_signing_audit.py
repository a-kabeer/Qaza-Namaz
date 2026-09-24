#!/usr/bin/env python3
"""Audit Android release signing compatibility.

The audit reports only package/certificate metadata, never passwords or private
key material. It can inspect a release APK or the production keystore.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path


def run(command: list[str]) -> str:
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"Required tool not found: {command[0]}") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout).strip()
        raise SystemExit(f"Command failed: {command[0]} {detail}") from exc
    return result.stdout


def normalize_fingerprint(value: str) -> str:
    return re.sub(r"[^0-9A-Fa-f]", "", value).lower()


def firebase_sha1s(config_path: Path, package: str) -> list[str]:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    values: list[str] = []
    for client in config.get("client", []):
        android = client.get("client_info", {}).get("android_client_info", {})
        if android.get("package_name") != package:
            continue
        for oauth in client.get("oauth_client", []):
            info = oauth.get("android_info", {})
            if (
                oauth.get("client_type") == 1
                and info.get("package_name") == package
                and info.get("certificate_hash")
            ):
                values.append(normalize_fingerprint(info["certificate_hash"]))
    return sorted(set(values))


def _android_sdk_tool(name: str) -> str | None:
    """Resolve an Android SDK command from PATH or installed build-tools."""
    direct = shutil.which(name)
    if direct:
        return direct

    sdk_roots = [
        os.environ.get("ANDROID_SDK_ROOT"),
        os.environ.get("ANDROID_HOME"),
        "/usr/local/lib/android/sdk",
    ]
    for root in sdk_roots:
        if not root:
            continue
        build_tools = Path(root) / "build-tools"
        if not build_tools.is_dir():
            continue
        candidates = sorted(
            (p for p in build_tools.glob(f"*/{name}") if p.is_file()),
            reverse=True,
        )
        if candidates:
            return str(candidates[0])

    return None


def apk_audit(apk: Path) -> tuple[str, str, str]:
    apksigner = _android_sdk_tool("apksigner")
    if not apksigner:
        raise SystemExit(
            "apksigner was not found on PATH or in the installed Android SDK "
            "build-tools."
        )

    output = run([apksigner, "verify", "--print-certs", str(apk)])
    sha1 = ""
    sha256 = ""
    for line in output.splitlines():
        if "Signer #1 certificate SHA-256 digest:" in line:
            sha256 = normalize_fingerprint(line.split(":", 1)[1])
        elif "Signer #1 certificate SHA-1 digest:" in line:
            sha1 = normalize_fingerprint(line.split(":", 1)[1])

    if not sha256:
        raise SystemExit("Could not extract the APK signing certificate SHA-256.")

    package = "unknown"
    aapt = _android_sdk_tool("aapt2") or _android_sdk_tool("aapt")
    if aapt:
        badging = run([aapt, "dump", "badging", str(apk)])
        match = re.search(r"package: name='([^']+)'", badging)
        if match:
            package = match.group(1)

    return package, sha1, sha256


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


def env_secret(name: str | None, description: str) -> str | None:
    if not name:
        return None
    value = os.environ.get(name)
    if value is None:
        raise SystemExit(f"Environment variable for {description} is not set: {name}")
    return value


def print_firebase_comparison(
    config_path: Path, package: str, sha1: str
) -> bool:
    """Reports whether this signing certificate is registered with Firebase.

    Returns False when the answer is "no" or "cannot tell". An unregistered
    certificate is the exact cause of a Google sign-in that opens the account
    chooser, completes, and then hands back no ID token.
    """
    if not config_path.exists():
        print("Firebase SHA-1 comparison: SKIPPED (config not found)")
        return False

    registered = firebase_sha1s(config_path, package)
    matched = bool(sha1 and sha1 in registered)
    print("Firebase SHA-1 match:", "YES" if matched else "NO")
    print("Firebase registered SHA-1 count:", len(registered))
    if not matched:
        print(
            "WARNING: Firebase OAuth SHA-1 registration does not match this "
            "signing certificate. This affects Google/Firebase authentication; "
            "it does not by itself determine Android package-install identity."
        )
    return matched


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--apk", type=Path)
    source.add_argument("--keystore", type=Path)
    parser.add_argument("--alias")
    parser.add_argument("--store-password", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--key-password", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--store-password-env")
    parser.add_argument("--key-password-env")
    parser.add_argument("--firebase-package")
    parser.add_argument(
        "--firebase-config",
        type=Path,
        default=Path("android/app/google-services.json"),
    )
    parser.add_argument(
        "--require-firebase-match",
        action="store_true",
        help=(
            "Exit non-zero unless this signing certificate's SHA-1 is "
            "registered as an Android OAuth client in google-services.json. "
            "An artifact signed with an unregistered certificate cannot "
            "complete Google Sign-In, so shipping one is a build failure."
        ),
    )
    args = parser.parse_args()

    if args.apk:
        package, sha1, sha256 = apk_audit(args.apk)
        print(f"Package ID: {package}")
        print(f"APK SHA-1: {sha1 or 'unavailable'}")
        print(f"APK SHA-256: {sha256}")
        if args.firebase_package and package not in ("unknown", args.firebase_package):
            raise SystemExit(
                f"APK package ID {package} does not match the expected "
                f"Firebase package {args.firebase_package}."
            )
        matched = False
        if package != "unknown":
            matched = print_firebase_comparison(
                args.firebase_config, package, sha1
            )
        if args.require_firebase_match and not matched:
            raise SystemExit(
                "Signing certificate is not registered in Firebase. Add "
                f"SHA-1 {sha1 or 'unavailable'} (and the matching SHA-256) to "
                f"the Android app for {package} in the Firebase console, then "
                "download the updated google-services.json."
            )
        return 0

    if not args.alias:
        raise SystemExit("--alias is required with --keystore.")

    store_password = (
        args.store_password
        if args.store_password is not None
        else env_secret(args.store_password_env, "keystore password")
    )
    key_password = (
        args.key_password
        if args.key_password is not None
        else env_secret(args.key_password_env, "key password")
    )
    if store_password is None:
        raise SystemExit(
            "Provide --store-password or --store-password-env for keystore access."
        )

    sha1, sha256 = keystore_audit(
        args.keystore, args.alias, store_password, key_password
    )
    print(f"Keystore SHA-1: {sha1}")
    print(f"Keystore SHA-256: {sha256}")

    if args.firebase_package:
        print_firebase_comparison(args.firebase_config, args.firebase_package, sha1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
