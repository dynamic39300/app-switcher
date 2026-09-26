#!/bin/bash
# Local checks; PostgreSQL concurrency runs only when DATABASE_URL points to an isolated test database.
set -euo pipefail
cd "$(dirname "$0")/.."
uv sync --frozen --project web
uv run --frozen --project web ruff check web scripts/app_bundle.py scripts/release_manifest.py scripts/test_app_bundle.py scripts/verify_postgres_restore.py
uv run --frozen --project web ruff format --check web
uv run --frozen --project web python web/manage.py check
uv run --frozen --project web python web/manage.py makemigrations --check --dry-run
uv run --frozen --project web python web/manage.py collectstatic --noinput
uv run --frozen --project web python web/manage.py test commerce --noinput
node --check web/static/app.js
python3 scripts/test_app_bundle.py
bash -n scripts/build_app.sh scripts/release_macos.sh
swift build
swift run CoreTests
.build/debug/AppSwitcherApp --verify-commerce
python3 .framework/scripts/check_framework.py --root .
git diff --check
echo '本地检查完成。SQLite skip 不代表 PostgreSQL 并发通过；模拟不代表生产交易/分发通过。'
