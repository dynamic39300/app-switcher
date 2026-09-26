#!/usr/bin/env python3
"""Freeze source before compilation; record notarized artifacts from that signed build evidence."""

import argparse
import hashlib
import json
import os
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source_digest():
    source = hashlib.sha256()
    files = [ROOT / "Package.swift", ROOT / "VERSION"]
    if (ROOT / "Package.resolved").exists():
        files.append(ROOT / "Package.resolved")
    files += list((ROOT / "Sources").rglob("*.swift"))
    for extension in ("*.py", "*.sh", "*.swift"):
        files += list((ROOT / "scripts").glob(extension))
    for path in sorted(files):
        source.update(
            str(path.relative_to(ROOT)).encode() + b"\0" + path.read_bytes() + b"\0"
        )
    return source.hexdigest()


def capture(destination):
    record = {
        "product": "AppSwitcher",
        "version": (ROOT / "VERSION").read_text().strip(),
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "buildOS": platform.platform(),
        "swiftVersion": subprocess.check_output(
            ["swift", "--version"], text=True
        ).strip(),
        "commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "workingTreeModified": bool(
            subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)
        ),
        "sourceSHA256": source_digest(),
        "configuration": os.getenv("APPSWITCHER_CONFIGURATION", "release"),
        "buildKind": os.getenv("APPSWITCHER_BUILD_KIND", "local"),
        "commerceMode": os.getenv("APPSWITCHER_COMMERCE_MODE", "local"),
        "serviceURL": os.getenv("APPSWITCHER_SERVICE_URL", ""),
    }
    destination.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")


def verify_source(record, current_digest, current_version):
    if (
        record.get("sourceSHA256") != current_digest
        or record.get("version") != current_version
    ):
        raise ValueError("构建期间源码或版本改变，请在源码稳定后重新构建；未签名发布")


def finalize_build(provenance, executable):
    record = json.loads(provenance.read_text())
    verify_source(record, source_digest(), (ROOT / "VERSION").read_text().strip())
    architectures = subprocess.check_output(
        ["lipo", "-archs", str(executable)], text=True
    ).split()
    if record["buildKind"] == "distribution" and architectures != ["arm64"]:
        raise ValueError("正式首发仅允许已验证的 arm64 Mach-O，不能误标架构")
    record["architectures"] = architectures
    # Signing mutates Mach-O; the final DMG checksum is recorded separately after stapling.
    record["preSigningExecutableSHA256"] = hashlib.sha256(
        executable.read_bytes()
    ).hexdigest()
    record["compiledAt"] = datetime.now(timezone.utc).isoformat()
    provenance.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")


def artifact(dmg, receipt, provenance, destination):
    notary = json.loads(receipt.read_text())
    build = json.loads(provenance.read_text())
    if notary.get("status") != "Accepted":
        raise ValueError("Notarization not accepted")
    if (
        build.get("architectures") != ["arm64"]
        or build.get("buildKind") != "distribution"
    ):
        raise ValueError("Missing measured distribution build provenance")
    digest = hashlib.sha256()
    with dmg.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    result = {
        "product": "AppSwitcher",
        "version": build["version"],
        "file": dmg.name,
        "sha256": digest.hexdigest(),
        "architecture": build["architectures"][0],
        "minimumOS": "15.0",
        "notarizationID": notary["id"],
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "build": build,
        "independentInstallVerified": False,
    }
    # Do not reread the active checkout after notarization: only the frozen, signed bundle record.
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("capture")
    p.add_argument("destination", type=Path)
    p = commands.add_parser("verify")
    p.add_argument("provenance", type=Path)
    p.add_argument("executable", type=Path)
    p = commands.add_parser("artifact")
    for name in ("dmg", "receipt", "provenance", "destination"):
        p.add_argument(name, type=Path)
    args = parser.parse_args()
    try:
        if args.command == "capture":
            capture(args.destination)
        elif args.command == "verify":
            finalize_build(args.provenance, args.executable)
        else:
            artifact(args.dmg, args.receipt, args.provenance, args.destination)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__":
    main()
