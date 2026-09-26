#!/usr/bin/env python3
"""Validated public bundle metadata and non-destructive artifact publication."""

import argparse
import base64
import ipaddress
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.appswitcher.app"


def public_distribution_host(hostname):
    """Reject known placeholder/intranet targets without performing DNS or network requests."""
    # Foundation decodes %-escapes in URL.host, whereas urllib leaves them intact.
    # Keep the build-time and runtime interpretation identical by rejecting encoded hosts.
    if "%" in hostname:
        return False
    try:
        host = hostname.encode("idna").decode("ascii").lower()
    except UnicodeError:
        return False
    host = host.removesuffix(".")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        labels = host.split(".")
        if (
            len(host) > 253
            or len(labels) < 2
            or any(
                not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label)
                for label in labels
            )
            # Legacy shortened/octal/hex IP forms accepted by system URL resolution
            # must not be treated as public DNS names after strict ip_address rejects them.
            or re.fullmatch(r"(?:[0-9]+|0x[0-9a-f]+)", labels[-1])
            or host.endswith((".localhost", ".local", ".test", ".invalid", ".example"))
        ):
            return False
        # IANA documentation domains also include their subdomains.
        return not any(
            host == domain or host.endswith("." + domain)
            for domain in ("example.com", "example.net", "example.org")
        )
    return address.is_global and not address.is_multicast


def metadata(env=None):
    env = os.environ if env is None else env
    version = (ROOT / "VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("VERSION 必须为三个非负整数组成的版本号")
    kind = env.get("APPSWITCHER_BUILD_KIND", "local")
    configuration = env.get("APPSWITCHER_CONFIGURATION", "release")
    mode = env.get("APPSWITCHER_COMMERCE_MODE", "local")
    if kind not in {"local", "distribution"} or configuration not in {
        "debug",
        "release",
    }:
        raise ValueError("构建类型或 configuration 无效")
    if mode not in {"local", "commercial"}:
        raise ValueError("APPSWITCHER_COMMERCE_MODE 必须为 local/commercial")
    if kind == "distribution" and (mode != "commercial" or configuration != "release"):
        raise ValueError("正式分发必须为 release + commercial，不允许本地授权模式")
    result = {
        "CFBundleName": "AppSwitcher",
        "CFBundleDisplayName": "AppSwitcher",
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleVersion": version,
        "CFBundleShortVersionString": version,
        "CFBundleExecutable": "AppSwitcher",
        "CFBundlePackageType": "APPL",
        "CFBundleIconFile": "AppIcon",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "15.0",
        "CFBundleURLTypes": [
            {
                "CFBundleURLName": BUNDLE_ID + ".auth",
                "CFBundleURLSchemes": ["appswitcher"],
                "CFBundleTypeRole": "Viewer",
            }
        ],
        "AppSwitcherCommerceMode": mode,
    }
    if mode == "commercial":
        service = env.get("APPSWITCHER_SERVICE_URL", "").rstrip("/")
        u = urlsplit(service)
        if any(
            character.isspace() or ord(character) < 32 or ord(character) == 127
            for character in service
        ):
            raise ValueError("服务地址不能包含空白或控制字符")
        # Accessing .port also rejects malformed/non-numeric/out-of-range ports.
        port = u.port
        if port is not None and not 1 <= port <= 65535:
            raise ValueError("服务端口必须介于1与65535之间")
        local = u.hostname in {"localhost", "127.0.0.1", "::1"}
        if (
            not u.hostname
            or u.username
            or u.password
            or u.query
            or u.fragment
            or u.path
            or (
                u.scheme != "https"
                and not (
                    u.scheme == "http"
                    and local
                    and kind == "local"
                    and configuration == "debug"
                )
            )
        ):
            raise ValueError(
                "服务地址必须为 HTTPS origin；仅本地 Debug 允许 loopback HTTP"
            )
        if kind == "distribution" and not public_distribution_host(u.hostname):
            raise ValueError("正式分发不能绑定示例、测试、回环或非公网服务")
        public_key = env.get("APPSWITCHER_LICENSE_PUBLIC_KEY", "")
        try:
            raw = base64.b64decode(public_key, validate=True)
        except (ValueError, TypeError):
            raise ValueError(
                "授权公钥必须为 base64 编码的 32-byte Ed25519 公钥"
            ) from None
        if len(raw) != 32 or raw == bytes(32):
            raise ValueError("授权公钥必须为非零的 32-byte Ed25519 公钥")
        result.update(
            AppSwitcherServiceURL=service, AppSwitcherLicensePublicKey=public_key
        )
    elif env.get("APPSWITCHER_SERVICE_URL") or env.get(
        "APPSWITCHER_LICENSE_PUBLIC_KEY"
    ):
        raise ValueError("提供商业配置时需明确 APPSWITCHER_COMMERCE_MODE=commercial")
    return result


def validate_destination(path):
    path = Path(path).absolute()
    if path.suffix != ".app" or path.is_symlink() or not path.name[:-4]:
        raise ValueError("输出必须为非符号链接的 .app 路径")
    # Resolve parents to detect accidental aliases into the currently installed app.
    if path.exists():
        try:
            with (path / "Contents/Info.plist").open("rb") as f:
                identity = plistlib.load(f).get("CFBundleIdentifier")
        except (OSError, ValueError, plistlib.InvalidFileException):
            raise ValueError(
                "已有输出不是可确认身份的 AppSwitcher 包，拒绝替换"
            ) from None
        if identity != BUNDLE_ID:
            raise ValueError("已有输出属于其他应用，拒绝替换")
    return path


def publish(source, destination):
    """Copy and verify before swap; retain any previous bundle instead of deleting it."""
    destination = validate_destination(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(
        tempfile.mkdtemp(prefix=".appswitcher-publish-", dir=destination.parent)
    )
    backup = None
    try:
        candidate = staging / "AppSwitcher.app"
        subprocess.run(
            ["ditto", "--norsrc", "--noextattr", str(source), str(candidate)],
            check=True,
        )
        subprocess.run(
            ["codesign", "--verify", "--deep", "--strict", str(candidate)], check=True
        )
        if destination.exists():
            backup = destination.with_name(
                destination.name + ".previous-" + staging.name.rsplit("-", 1)[-1]
            )
            if backup.exists():
                raise ValueError("备份位置已存在，拒绝覆盖")
            destination.rename(backup)
        try:
            candidate.rename(destination)
        except BaseException:
            if backup is not None:
                backup.rename(destination)
            raise
        print("已生成: " + str(destination))
        if backup:
            print("原输出保留于: " + str(backup))
    finally:
        shutil.rmtree(staging)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("validate")
    p = commands.add_parser("plist")
    p.add_argument("destination", type=Path)
    p = commands.add_parser("publish")
    p.add_argument("source", type=Path)
    p.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "validate":
            metadata()
            validate_destination(
                os.environ.get("APPSWITCHER_OUTPUT", "build/AppSwitcher.app")
            )
            print("构建配置有效（不代表正式签名/公证通过）")
        elif args.command == "plist":
            with args.destination.open("wb") as f:
                plistlib.dump(metadata(), f)
        else:
            publish(args.source, args.destination)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__":
    main()
