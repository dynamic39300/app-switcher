#!/usr/bin/env python3
"""Check framework documents and snapshot integrity; never run business checks.

This file is deliberately self-contained so a copied snapshot needs only Python.
The source-repository initializer and comparison tool also reuse its helpers.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
from urllib.parse import unquote, urlsplit


PROFILES = ("lean", "product", "platform")
VERSION_RE = re.compile(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\Z")
HASH_RE = re.compile(r"[0-9a-f]{64}\Z")
IGNORED_DIRS = {".git", ".venv", "venv", "node_modules", "__pycache__", ".pytest_cache"}


class FrameworkError(ValueError):
    """Invalid framework input, unsafe path, or unreadable required artifact."""


def checked_path(value: str | Path) -> Path:
    """Return an absolute lexical path, rejecting symlinks before resolving '..'."""
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        if current.is_symlink():
            raise FrameworkError(f"拒绝符号链接路径: {current}")
    return Path(os.path.abspath(path))


def relative_path(value: object) -> str:
    """Manifest/config paths use canonical POSIX relative spelling only."""
    if not isinstance(value, str) or not value or "\\" in value or ":" in value or "\x00" in value:
        raise FrameworkError(f"非法相对路径: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in {"", ".", ".."} for p in value.split("/")):
        raise FrameworkError(f"非法相对路径: {value!r}")
    if str(path) != value:
        raise FrameworkError(f"非规范路径: {value!r}")
    return value


def within(base: Path, relative: str) -> Path:
    name = relative_path(relative)
    base = checked_path(base)
    result = checked_path(base / name)
    if not result.is_relative_to(base):
        raise FrameworkError(f"路径越界: {relative}")
    return result


def sha256(path: Path) -> str:
    path = checked_path(path)
    if not path.is_file():
        raise FrameworkError(f"不是普通文件: {path}")
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    path = checked_path(path)
    try:
        def reject_duplicates(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise FrameworkError(f"JSON 含重复键 {key!r}: {path}")
                result[key] = value
            return result
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicates)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise FrameworkError(f"无法读取 JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise FrameworkError(f"JSON 顶层必须为对象: {path}")
    return value


def valid_date(value: object, field: str) -> dt.date:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise FrameworkError(f"{field} 必须为 YYYY-MM-DD: {value!r}")
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise FrameworkError(f"{field} 日期无效: {value}") from exc


def require_version(value: object) -> str:
    if not isinstance(value, str) or not VERSION_RE.fullmatch(value):
        raise FrameworkError(f"非法框架版本: {value!r}")
    return value


def load_config(root: Path) -> dict:
    config = read_json(within(root, "framework.json"))
    if type(config.get("schema_version")) is not int or config["schema_version"] != 1:
        raise FrameworkError("framework.json schema_version 必须为 1")
    require_version(config.get("version"))
    valid_date(config.get("reviewed_on"), "reviewed_on")
    if config.get("profiles") != list(PROFILES):
        raise FrameworkError(f"framework.json profiles 必须为 {list(PROFILES)}")
    all_paths = []
    for field in ("snapshot_paths", "snapshot_tools"):
        values = config.get(field)
        if not isinstance(values, list) or not values:
            raise FrameworkError(f"framework.json {field} 必须为非空路径数组")
        all_paths.extend(relative_path(p) for p in values)
    if len(set(all_paths)) != len(all_paths):
        raise FrameworkError("framework.json 快照路径重复")
    relative_path(config.get("project_template"))
    return config


def walk_files(root: Path, *, ignore_generated: bool = False, skip_symlinks: bool = False) -> dict[str, Path]:
    root = checked_path(root)
    if not root.is_dir():
        raise FrameworkError(f"目录不存在: {root}")
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs.sort()
        files.sort()
        if ignore_generated:
            dirs[:] = [name for name in dirs if name not in IGNORED_DIRS]
        if skip_symlinks:
            # Document discovery may coexist with unrelated business symlinks.
            # Prune directory links before os.walk can descend, and skip files.
            dirs[:] = [name for name in dirs if not (Path(directory) / name).is_symlink()]
            files = [name for name in files if not (Path(directory) / name).is_symlink()]
        for name in dirs + files:
            path = Path(directory) / name
            if path.is_symlink():
                raise FrameworkError(f"拒绝符号链接: {path}")
        for name in files:
            path = Path(directory) / name
            if not path.is_file():
                raise FrameworkError(f"拒绝非普通文件: {path}")
            result[path.relative_to(root).as_posix()] = path
    return result


def snapshot_sources(root: Path, config: dict) -> dict[str, Path]:
    result = {}
    for name in config["snapshot_paths"] + config["snapshot_tools"]:
        path = within(root, name)
        if path.is_dir():
            entries = {f"{name}/{suffix}": p for suffix, p in walk_files(path).items()}
        elif path.is_file():
            entries = {name: path}
        else:
            raise FrameworkError(f"快照源不存在: {name}")
        for key, value in entries.items():
            if key in result:
                raise FrameworkError(f"快照路径重叠: {key}")
            if key in {"README.md", "manifest.json"}:
                raise FrameworkError(f"快照源占用了生成器保留路径: {key}")
            result[key] = value
    return result


def snapshot_readme(version: str) -> str:
    return (
        f"# 框架快照 {version}\n\n"
        "这是本项目采用的规范基线；项目差异请记录到项目自身的 overrides。\n\n"
        "- [文档索引](docs/README.md)\n"
        "- [材料模板](templates/artifacts/README.md)\n"
        "- [完整示例](examples/README.md)\n\n"
        "manifest.json 记录复制基线。检查器仅校验文档与快照，不执行业务测试。\n"
    )


def load_manifest(snapshot: Path) -> dict:
    manifest = read_json(within(snapshot, "manifest.json"))
    if type(manifest.get("schema_version")) is not int or manifest["schema_version"] != 1:
        raise FrameworkError("manifest schema_version 必须为 1")
    require_version(manifest.get("version"))
    valid_date(manifest.get("generated_on"), "generated_on")
    for field in ("files", "template_files"):
        mapping = manifest.get(field)
        if not isinstance(mapping, dict) or not mapping:
            raise FrameworkError(f"manifest {field} 必须为非空路径/哈希对象")
        for name, digest in mapping.items():
            relative_path(name)
            if not isinstance(digest, str) or not HASH_RE.fullmatch(digest):
                raise FrameworkError(f"manifest {field} 哈希无效: {name}")
            if field == "files":
                if name == "manifest.json":
                    raise FrameworkError("manifest 不能包含自身哈希")
                # Validate every component before any caller reads a listed file.
                within(snapshot, name)
    required = {"README.md", "VERSION", "framework.json", "scripts/check_framework.py"}
    if not required.issubset(manifest["files"]):
        raise FrameworkError(f"manifest 缺少必要快照文件: {sorted(required - manifest['files'].keys())}")
    return manifest


def snapshot_drift(snapshot: Path, manifest: dict) -> dict[str, list[str]]:
    actual = walk_files(snapshot)
    actual.pop("manifest.json", None)
    expected = manifest["files"]
    return {
        "missing": sorted(expected.keys() - actual.keys()),
        "modified": sorted(name for name in expected.keys() & actual.keys() if sha256(actual[name]) != expected[name]),
        "untracked": sorted(actual.keys() - expected.keys()),
    }


def without_code(markdown: str) -> str:
    """Remove fenced/indented examples and inline code before checking links."""
    output = []
    fence_char = None
    fence_len = 0
    for line in markdown.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if fence_char:
            if re.match(r"^\s{0,3}" + re.escape(fence_char) + "{" + str(fence_len) + r",}\s*$", line):
                fence_char = None
            output.append("")
        elif marker:
            fence_char = marker.group(1)[0]
            fence_len = len(marker.group(1))
            output.append("")
        elif line.startswith("    ") or line.startswith("\t"):
            output.append("")
        else:
            output.append(line)
    text = "\n".join(output)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return re.sub(r"(`+).*?\1", "", text, flags=re.S)


def markdown_targets(markdown: str) -> list[str]:
    text = without_code(markdown)
    targets = []
    # Covers standard inline links/images, optional titles, and one nested pair.
    pattern = r"!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|(?:[^\s()\\]|\\.|\([^()\n]*\))+)(?:\s+[^)\n]*)?\s*\)"
    targets.extend(match.group(1).strip("<>") for match in re.finditer(pattern, text))
    for match in re.finditer(r"^\s{0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|\S+)", text, flags=re.M):
        targets.append(match.group(1).strip("<>"))
    return targets


def check_links(path: Path, root: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for raw in markdown_targets(text):
        if "{{" in raw or raw.startswith("#"):
            continue
        target = urlsplit(raw)
        if target.scheme or target.netloc or not target.path:
            continue
        decoded = unquote(target.path)
        # Repository-root links are supported, but may not escape the selected root.
        candidate = root / decoded.lstrip("/") if decoded.startswith("/") else path.parent / decoded
        try:
            candidate = checked_path(candidate)
            if not candidate.is_relative_to(root):
                raise FrameworkError("链接越出检查根目录")
            if not candidate.exists():
                raise FrameworkError("目标不存在")
        except (FrameworkError, OSError, ValueError) as exc:
            errors.append(f"{path.relative_to(root)}: 链接 {raw!r}: {exc}")


def check_metadata(path: Path, label: str, errors: list[str], warnings: list[str], today: dt.date, strict: bool) -> None:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\s*\n(.*?)\n---(?:\s*\n|$)", text, flags=re.S)
    if not match:
        errors.append(f"{label}: 缺少 YAML 元数据")
        return
    fields = {}
    for line in match.group(1).splitlines():
        field = re.match(r"^([a-z_]+):\s*(.*?)\s*$", line)
        if field:
            key, value = field.groups()
            if key in fields:
                errors.append(f"{label}: 重复元数据 {key}")
            fields[key] = value.strip("\"'")
    for key in ("owner_role", "status", "last_reviewed", "next_review_due"):
        if not fields.get(key):
            errors.append(f"{label}: 缺少元数据 {key}")
    try:
        reviewed = valid_date(fields.get("last_reviewed"), "last_reviewed")
        due = valid_date(fields.get("next_review_due"), "next_review_due")
        if due < reviewed:
            errors.append(f"{label}: next_review_due 早于 last_reviewed")
        if reviewed > today:
            warnings.append(f"{label}: last_reviewed 晚于运行日期 {today}")
        if due < today:
            (errors if strict else warnings).append(f"{label}: 复查已逾期 {due}")
    except FrameworkError as exc:
        errors.append(f"{label}: {exc}")


def default_root() -> Path:
    container = Path(__file__).resolve().parent.parent
    return container.parent if container.name == ".framework" else container


def check(root: Path, *, strict_review_dates: bool = False, today: dt.date | None = None) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    today = today or dt.date.today()
    result = {"errors": errors, "warnings": warnings, "markdown_files": 0, "scope": "documents-and-framework-only"}
    try:
        root = checked_path(root)
        generated = (root / ".framework").exists() or (root / ".framework").is_symlink()
        baseline = within(root, ".framework") if generated else root
        config = load_config(baseline)
        version = within(baseline, "VERSION").read_text(encoding="utf-8").strip()
        if version != config["version"]:
            errors.append("VERSION 与 framework.json 的 version 不一致")
        if generated:
            manifest = load_manifest(baseline)
            if manifest["version"] != config["version"]:
                errors.append("manifest 与 framework.json 的 version 不一致")
            drift = snapshot_drift(baseline, manifest)
            for kind, paths in drift.items():
                errors.extend(f"快照 {kind}: {name}" for name in paths)
        else:
            for name in ("README.md", "AGENTS.md", "CLAUDE.md", "CLOUD.md", "CONTEXT.md", "CONTRIBUTING.md", "CHANGELOG.md", "VERSION", "docs/README.md", "scripts/init_project.py", "scripts/check_framework.py", "scripts/compare_framework.py"):
                if not within(root, name).is_file():
                    errors.append(f"缺少框架必需文件: {name}")
            snapshot_sources(root, config)
            template = within(root, config["project_template"])
            if not walk_files(template):
                errors.append("项目模板为空")
        files = walk_files(root, ignore_generated=True, skip_symlinks=True)
        template_prefix = config["project_template"] + "/"
        for name, path in files.items():
            if path.suffix.lower() != ".md":
                continue
            # Project templates contain links resolved only after rendering.
            if not generated and name.startswith(template_prefix):
                continue
            check_links(path, root, errors)
            result["markdown_files"] += 1
        for directory in ("docs/handbook", "docs/standards", "docs/research"):
            for suffix, path in walk_files(within(baseline, directory)).items():
                if path.suffix.lower() == ".md" and path.name.lower() != "readme.md":
                    check_metadata(path, path.relative_to(root).as_posix(), errors, warnings, today, strict_review_dates)
    except (FrameworkError, OSError, UnicodeError, ValueError) as exc:
        errors.append(str(exc))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="仅检查文档、版本与框架快照；不执行业务构建、测试或发布。")
    parser.add_argument("--root", type=Path, default=default_root())
    parser.add_argument("--strict-review-dates", action="store_true")
    args = parser.parse_args(argv)
    report = check(args.root, strict_review_dates=args.strict_review_dates)
    for warning in report["warnings"]:
        print(f"WARNING: {warning}")
    for error in report["errors"]:
        print(f"ERROR: {error}")
    print(f"文档/框架检查: {report['markdown_files']} 个 Markdown，{len(report['errors'])} 个错误，{len(report['warnings'])} 个警告。")
    print("本工具未执行业务代码检查、测试或发布验证。")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
