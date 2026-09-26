#!/usr/bin/env python3
"""Release boundary tests: unsafe configurations must fail before building/signing."""

import base64
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from app_bundle import BUNDLE_ID, metadata, publish, validate_destination
from release_manifest import verify_source


class BundleBoundaryTests(unittest.TestCase):
    def commercial(self):
        return {
            "APPSWITCHER_COMMERCE_MODE": "commercial",
            # Syntactic fixture only: no network request or domain ownership assertion.
            "APPSWITCHER_SERVICE_URL": "https://switch.product-domain.com",
            "APPSWITCHER_LICENSE_PUBLIC_KEY": base64.b64encode(
                bytes(range(32))
            ).decode(),
        }

    def test_source_changes_during_build_are_rejected(self):
        frozen = {"sourceSHA256": "original", "version": "0.4.0"}
        verify_source(frozen, "original", "0.4.0")
        with self.assertRaises(ValueError):
            verify_source(frozen, "changed", "0.4.0")
        with self.assertRaises(ValueError):
            verify_source(frozen, "original", "0.4.1")

    def test_local_has_no_service_and_declares_callback(self):
        info = metadata({})
        self.assertEqual(info["AppSwitcherCommerceMode"], "local")
        self.assertNotIn("AppSwitcherServiceURL", info)
        self.assertEqual(
            info["CFBundleURLTypes"][0]["CFBundleURLSchemes"], ["appswitcher"]
        )

    def test_distribution_requires_commercial_release(self):
        for update in (
            {},
            {"APPSWITCHER_COMMERCE_MODE": "local"},
            {"APPSWITCHER_CONFIGURATION": "debug"},
        ):
            with self.subTest(update=update), self.assertRaises(ValueError):
                metadata({"APPSWITCHER_BUILD_KIND": "distribution", **update})
        info = metadata({**self.commercial(), "APPSWITCHER_BUILD_KIND": "distribution"})
        self.assertEqual(
            info["AppSwitcherServiceURL"], "https://switch.product-domain.com"
        )

    def test_distribution_rejects_placeholder_and_nonpublic_destinations(self):
        hosts = [
            "example.com",
            "appswitcher.example.com",
            "example.net",
            "EXAMPLE.ORG.",
            "localhost.",
            "app.localhost",
            "app.local",
            "app.invalid.",
            "app.test",
            "intranet",
            "127.0.0.2",
            "192.168.1.2",
            "169.254.1.2",
            "0.0.0.0",
            "224.0.0.1",
            "[::1]",
            "[::ffff:127.0.0.1]",
            "[fc00::1]",
            "[fe80::1]",
            "127.1",
            "127.000.0.1",
            "0x7f.0.0.1",
            "0177.0.0.1",
            "0x7f.0x0.0x0.0x1",
            "%31%32%37.0.0.1",
            "127.0.0.%31",
            "example.com%2e",
            "app.localhost%2e",
            "１２７。０。０。１",
            "bad_.public.com",
            "app.public.com..",
        ]
        for host in hosts:
            with self.subTest(host=host), self.assertRaises(ValueError):
                metadata(
                    {
                        **self.commercial(),
                        "APPSWITCHER_BUILD_KIND": "distribution",
                        "APPSWITCHER_SERVICE_URL": "https://" + host,
                    }
                )
        # Local commercial Release fixtures may still use a reserved HTTPS origin;
        # only their distribution as a real production application is prohibited.
        local = metadata(
            {
                **self.commercial(),
                "APPSWITCHER_SERVICE_URL": "https://release-check.example.invalid",
            }
        )
        self.assertEqual(local["AppSwitcherCommerceMode"], "commercial")

    def test_invalid_ports_and_control_characters_are_rejected(self):
        for origin in [
            "https://switch.product-domain.com:invalid",
            "https://switch.product-domain.com:99999",
            "https://switch.product-domain.com:0",
            "https://switch.product-domain.com\n",
            "https://switch.product-domain.com\t",
        ]:
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                metadata({**self.commercial(), "APPSWITCHER_SERVICE_URL": origin})
        self.assertEqual(
            metadata(
                {
                    **self.commercial(),
                    "APPSWITCHER_BUILD_KIND": "distribution",
                    "APPSWITCHER_SERVICE_URL": "https://switch.product-domain.com:443",
                }
            )["AppSwitcherCommerceMode"],
            "commercial",
        )

    def test_origin_rejects_credentials_query_paths_and_remote_http(self):
        for url in [
            "http://switch.example.org",
            "https://user:password@switch.example.org",
            "https://switch.example.org/api",
            "https://switch.example.org/?x=1",
            "https://switch.example.org/#fragment",
            "file:///tmp/",
            "",
        ]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                metadata({**self.commercial(), "APPSWITCHER_SERVICE_URL": url})

    def test_loopback_http_is_only_local_debug(self):
        env = {**self.commercial(), "APPSWITCHER_SERVICE_URL": "http://127.0.0.1:8766"}
        with self.assertRaises(ValueError):
            metadata(env)
        self.assertEqual(
            metadata({**env, "APPSWITCHER_CONFIGURATION": "debug"})[
                "AppSwitcherServiceURL"
            ],
            "http://127.0.0.1:8766",
        )
        with self.assertRaises(ValueError):
            metadata({**env, "APPSWITCHER_BUILD_KIND": "distribution"})

    def test_invalid_public_keys_and_implicit_mode_rejected(self):
        for key in [
            "",
            "not-a-key",
            base64.b64encode(bytes(32)).decode(),
            base64.b64encode(b"short").decode(),
        ]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                metadata({**self.commercial(), "APPSWITCHER_LICENSE_PUBLIC_KEY": key})
        with self.assertRaises(ValueError):
            metadata({"APPSWITCHER_SERVICE_URL": "https://switch.example.org"})

    def test_destination_refuses_other_app_symlink_or_unknown_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            other = parent / "Other.app"
            (other / "Contents").mkdir(parents=True)
            (other / "Contents/Info.plist").write_bytes(
                plistlib.dumps({"CFBundleIdentifier": "other.app"})
            )
            link = parent / "Link.app"
            link.symlink_to(other, target_is_directory=True)
            unknown = parent / "Unknown.app"
            unknown.mkdir()
            for path in [other, link, unknown, parent / "invalid", parent / ".app"]:
                with self.subTest(path=path.name), self.assertRaises(ValueError):
                    validate_destination(path)
            self.assertTrue(other.exists())

    def test_failed_signature_does_not_replace_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "AppSwitcher.app"
            (app / "Contents").mkdir(parents=True)
            (app / "Contents/Info.plist").write_bytes(
                plistlib.dumps({"CFBundleIdentifier": BUNDLE_ID})
            )
            sentinel = app / "Contents/preserved"
            sentinel.write_text("original artifact")
            with (
                patch(
                    "app_bundle.subprocess.run",
                    side_effect=RuntimeError("test copy failed"),
                ),
                self.assertRaises(RuntimeError),
            ):
                publish(Path(directory) / "source.app", app)
            self.assertEqual(sentinel.read_text(), "original artifact")
            self.assertEqual(
                sorted(p.name for p in Path(directory).iterdir()), ["AppSwitcher.app"]
            )


if __name__ == "__main__":
    unittest.main()
