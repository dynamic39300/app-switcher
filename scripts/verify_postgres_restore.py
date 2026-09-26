#!/usr/bin/env python3
"""Rehearse logical backup/restore using two disposable local PostgreSQL databases only."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit, urlunsplit

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parents[1]


def seed():
    sys.path.insert(0, str(ROOT / "web"))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    import django

    django.setup()
    from commerce.domain import (
        PLANS,
        confirm_refund,
        entitlement,
        grant_payment,
        start_trial,
    )
    from commerce.models import (
        Account,
        ConsentRecord,
        EntitlementGrant,
        Order,
        Refund,
        SupportMessage,
        SupportTicket,
    )
    from django.utils import timezone as django_time

    trial_user = Account.objects.create_user(
        username="restore-trial", email="restore-trial@example.test"
    )
    paid_user = Account.objects.create_user(
        username="restore-paid", email="restore-paid@example.test"
    )
    trial_user = start_trial(trial_user)
    orders = []
    for account, plans in (
        (trial_user, ("monthly", "yearly")),
        (paid_user, ("monthly", "quarterly")),
    ):
        for plan_id in plans:
            plan = PLANS[plan_id]
            order = Order.objects.create(
                account=account,
                idempotency_key=f"restore-{plan_id}",
                terms_version="2026-09-25",
                plan_id=plan_id,
                months=plan["months"],
                amount=plan["amount"],
                channel="simulated",
            )
            orders.append(
                grant_payment(
                    order.pk, f"restore-{order.pk}", django_time.now(), order.amount
                )
            )
        for document in ("terms", "privacy"):
            ConsentRecord.objects.create(
                account=account, document=document, version="2026-09-25"
            )
    refund = Refund.objects.create(
        order=orders[2], reason="Synthetic restore rehearsal", status="processing"
    )
    confirm_refund(refund.pk)
    ticket = SupportTicket.objects.create(
        account=trial_user, order=orders[0], subject="Synthetic support"
    )
    SupportMessage.objects.create(ticket=ticket, body="Synthetic customer message")
    SupportMessage.objects.create(
        ticket=ticket, body="Synthetic support reply", from_support=True
    )
    assert Account.objects.count() == 2
    assert Order.objects.filter(status="paid").count() == 3
    assert Order.objects.filter(status="refunded").count() == 1
    assert EntitlementGrant.objects.filter(revoked_at__isnull=False).count() == 1
    assert entitlement(trial_user)["status"] == "trial"
    assert entitlement(paid_user)["status"] == "paid"
    assert orders[0].grant.account_id == trial_user.pk
    print(
        "Synthetic seed: 2 accounts, 4 purchases, 1 confirmed refund, trial/renewal/support/consents."
    )


def snapshot(database_url):
    digest = hashlib.sha256()
    counts = {}
    with psycopg.connect(database_url) as conn:
        names = conn.execute(
            "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
        ).fetchall()
        for (name,) in names:
            rows = conn.execute(
                sql.SQL("SELECT * FROM {}").format(sql.Identifier(name))
            ).fetchall()
            encoded = sorted(
                json.dumps(row, default=str, ensure_ascii=False) for row in rows
            )
            digest.update(json.dumps([name, encoded], ensure_ascii=False).encode())
            counts[name] = len(rows)
        # Sequences must also survive, otherwise a restored DB can fail on the next insert.
        sequences = conn.execute(
            "SELECT sequencename, last_value FROM pg_sequences WHERE schemaname='public' ORDER BY sequencename"
        ).fetchall()
        digest.update(json.dumps(sequences, default=str).encode())
    return {
        "sha256": digest.hexdigest(),
        "tableCounts": counts,
        "sequenceCount": len(sequences),
    }


def local_test_url():
    raw_url = os.environ.get("DATABASE_URL", "")
    parsed = urlsplit(raw_url)
    if os.getenv("APPSWITCHER_ENV") != "test" or parsed.scheme not in {
        "postgres",
        "postgresql",
    }:
        raise ValueError(
            "Only APPSWITCHER_ENV=test with an explicit local PostgreSQL DATABASE_URL is accepted"
        )
    if (
        parsed.hostname not in {"127.0.0.1", "::1", "localhost"}
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(
            "Remote or parameterized database URLs are deliberately refused"
        )
    return raw_url, parsed


def verify(args):
    raw_url, parsed = local_test_url()
    run_id = uuid.uuid4().hex[:12]
    output = ROOT / "build" / "restore-rehearsals" / run_id
    output.mkdir(parents=True, mode=0o700)
    runtime = output / "runtime"
    names = [f"appswitcher_verify_{run_id}", f"appswitcher_restore_{run_id}"]
    urls = [urlunsplit(parsed._replace(path=f"/{name}")) for name in names]
    pg_env = {
        **os.environ,
        "PGHOST": parsed.hostname,
        "PGPORT": str(parsed.port or 5432),
        "PGUSER": unquote(parsed.username or ""),
        "PGPASSWORD": unquote(parsed.password or ""),
        "PGSSLMODE": os.getenv("DATABASE_SSLMODE", "disable"),
    }
    created = []
    started = time.monotonic()
    try:
        with psycopg.connect(
            raw_url, autocommit=True, sslmode=pg_env["PGSSLMODE"]
        ) as admin:
            server_version = admin.info.server_version
            for name in names:
                admin.execute(
                    sql.SQL(
                        "CREATE DATABASE {} TEMPLATE template0 ENCODING 'UTF8'"
                    ).format(sql.Identifier(name))
                )
                created.append(name)
        child_env = {
            **os.environ,
            "DATABASE_URL": urls[0],
            "DATABASE_SSLMODE": pg_env["PGSSLMODE"],
            "APPSWITCHER_RUNTIME_DIR": str(runtime),
        }
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "web/manage.py"),
                "migrate",
                "--noinput",
                "--verbosity",
                "0",
            ],
            env=child_env,
            check=True,
        )
        subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--seed"],
            env=child_env,
            check=True,
        )
        before = snapshot(urls[0])
        dump = output / "synthetic-backup.dump"
        subprocess.run(
            [
                str(args.pg_bin / "pg_dump"),
                "--format=custom",
                "--compress=0",
                "--file",
                str(dump),
                names[0],
            ],
            env=pg_env,
            check=True,
        )
        dump.chmod(0o600)
        restore_start = time.monotonic()
        subprocess.run(
            [
                str(args.pg_bin / "pg_restore"),
                "--single-transaction",
                "--no-owner",
                "--dbname",
                names[1],
                str(dump),
            ],
            env=pg_env,
            check=True,
        )
        after = snapshot(urls[1])
        restore_seconds = time.monotonic() - restore_start
        if before != after:
            raise ValueError("Restored rows or sequences do not match source")
        result = {
            "verifiedAt": datetime.now(timezone.utc).isoformat(),
            "scope": "isolated localhost logical restore of synthetic fixtures; not production PITR/RPO validation",
            "postgresVersionNumber": server_version,
            "result": "passed",
            "restoreAndVerifySeconds": round(restore_seconds, 3),
            "totalSeconds": round(time.monotonic() - started, 3),
            "backupBytes": dump.stat().st_size,
            "snapshot": after,
        }
        report = output / "report.json"
        report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(
            json.dumps(
                {
                    "result": "passed",
                    "tables": len(after["tableCounts"]),
                    "restoreAndVerifySeconds": result["restoreAndVerifySeconds"],
                    "report": str(report),
                },
                ensure_ascii=False,
            )
        )
    finally:
        # Only randomly named databases successfully created by this invocation are dropped.
        with psycopg.connect(
            raw_url, autocommit=True, sslmode=pg_env["PGSSLMODE"]
        ) as admin:
            for name in reversed(created):
                admin.execute(
                    sql.SQL("DROP DATABASE {} WITH (FORCE)").format(
                        sql.Identifier(name)
                    )
                )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pg-bin", type=Path, default=ROOT / "build/postgres-runtime/bin"
    )
    parser.add_argument("--seed", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        # libpq defaults such as PGHOSTADDR/PGSERVICE may override the connection target.
        # This process and its child tools receive only the explicit local test inputs.
        for name in list(os.environ):
            if name.startswith("PG"):
                del os.environ[name]
        _, parsed = local_test_url()
        if args.seed:
            if not re.fullmatch(r"/appswitcher_verify_[0-9a-f]{12}", parsed.path):
                raise ValueError(
                    "Seed is only for this rehearsal's disposable databases"
                )
            seed()
        else:
            verify(args)
    except (ValueError, OSError, psycopg.Error, subprocess.CalledProcessError) as exc:
        # Connection errors may contain credentials/DSNs: report only the type, not the full exception.
        print(
            f"Restore rehearsal failed ({type(exc).__name__}); no production database was targeted.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
