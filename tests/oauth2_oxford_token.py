#!/usr/bin/env python3
"""Offline checks for token-cache permissions and scope matching."""

import json
from pathlib import Path
import runpy
import stat
import tempfile
import time
import unittest
from unittest.mock import patch


helper = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/oauth2-oxford-token"))


class TokenCacheTests(unittest.TestCase):
    def test_cache_is_private_before_credentials_are_written(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder) / "state/token.json"
            payload = {"access_token": "fixture-access", "refresh_token": "fixture-refresh"}
            dump = json.dump

            def private_dump(data, stream, **kwargs):
                mode = stat.S_IMODE(Path(stream.name).stat().st_mode)
                self.assertEqual(mode, 0o600)
                dump(data, stream, **kwargs)

            with patch.object(json, "dump", private_dump):
                helper["save_cache"](cache, payload)
            self.assertEqual(json.loads(cache.read_text()), payload)
            self.assertEqual(stat.S_IMODE(cache.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(cache.parent.stat().st_mode), 0o700)
            self.assertEqual(list(cache.parent.iterdir()), [cache])

    def test_failed_write_preserves_cache_and_removes_temporary_file(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder) / "token.json"
            cache.write_text('{"access_token": "existing"}')
            with patch.object(json, "dump", side_effect=OSError("fixture failure")):
                with self.assertRaises(OSError):
                    helper["save_cache"](cache, {"access_token": "replacement"})
            self.assertEqual(json.loads(cache.read_text()), {"access_token": "existing"})
            self.assertEqual(list(cache.parent.iterdir()), [cache])

    def test_scope_names_must_match_exactly(self):
        scope = helper["IMAP_SCOPE"]
        cache = {"access_token": "fixture", "expires_at": time.time() + 3600}
        self.assertTrue(helper["token_valid"]({**cache, "scope": scope + " offline_access"}, [scope]))
        self.assertFalse(helper["token_valid"]({**cache, "scope": scope + ".Other"}, [scope]))
        self.assertFalse(helper["token_valid"]({**cache, "scope": scope, "expires_at": 0}, [scope]))


if __name__ == "__main__":
    unittest.main()
