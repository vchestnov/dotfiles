#!/usr/bin/python3
"""Offline checks for Firefox profile selection and symlinked launchers."""

import json
import os
from pathlib import Path
import runpy
import sqlite3
import subprocess
import tempfile
import unittest


repo = Path(__file__).resolve().parents[1]
find_profile = runpy.run_path(str(repo / "scripts/lib/firefox-profile.py"))["find_profile"]


class FirefoxProfileTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def modern_profiles(self, rows):
        database = self.root / "Profile Groups/group.sqlite"
        database.parent.mkdir()
        with sqlite3.connect(database) as connection:
            connection.execute("CREATE TABLE Profiles (name TEXT, path TEXT)")
            connection.executemany("INSERT INTO Profiles VALUES (?, ?)", rows)
        for _, path in rows:
            (self.root / path).mkdir()
        return database

    def legacy_profile(self, name, path, relative=True):
        self.root.joinpath("profiles.ini").write_text(
            f"[Profile0]\nName={name}\nPath={path}\nIsRelative={int(relative)}\n")

    def test_display_names_take_precedence_over_old_names_and_folder_names(self):
        database = self.modern_profiles([
            ("personal", "random.maths"), ("maths", "random.Profile 1")])
        self.legacy_profile("maths", "random.maths")
        before = database.read_bytes()
        self.assertEqual(find_profile("personal", [self.root]), self.root / "random.maths")
        self.assertEqual(find_profile("maths", [self.root]), self.root / "random.Profile 1")
        self.assertEqual(database.read_bytes(), before)

    def test_legacy_relative_and_absolute_profiles(self):
        for relative in (True, False):
            with self.subTest(relative=relative):
                profile = self.root / "old profile"
                profile.mkdir(exist_ok=True)
                self.legacy_profile("personal", profile.name if relative else profile, relative)
                self.assertEqual(find_profile("personal", [self.root]), profile)

    def test_missing_profile_is_rejected_without_creating_anything(self):
        with self.assertRaisesRegex(ValueError, "not found"):
            find_profile("personal", [self.root])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_ambiguous_profile_names_are_rejected(self):
        self.modern_profiles([("personal", "one"), ("personal", "two")])
        with self.assertRaisesRegex(ValueError, "multiple profiles"):
            find_profile("personal", [self.root])

    def test_missing_profile_folder_is_rejected(self):
        self.legacy_profile("personal", "missing")
        with self.assertRaisesRegex(ValueError, "directory is missing"):
            find_profile("personal", [self.root])

    def test_symlinked_launchers_forward_arguments_to_the_correct_profile(self):
        self.modern_profiles([("personal", "random.maths"), ("maths", "random.Profile 1")])
        launchers = self.root / "bin"
        launchers.mkdir()
        firefox = launchers / "firefox"
        firefox.write_text("#!/usr/bin/python3\nimport json, sys\n"
                           "print(json.dumps(sys.argv[1:]))\n")
        firefox.chmod(0o755)
        environment = dict(os.environ, FIREFOX_PROFILE_ROOT=str(self.root),
                           PATH=f"{launchers}:/usr/bin:/bin")
        for name, folder in [("personal", "random.maths"), ("maths", "random.Profile 1")]:
            with self.subTest(name=name):
                launcher = launchers / f"ff-{name}"
                launcher.symlink_to(repo / "scripts" / launcher.name)
                result = subprocess.run(
                    [str(launcher), "--new-window", "https://example.org/a b?q=x&y=z"],
                    env=environment, cwd="/tmp", text=True, capture_output=True, check=True)
                self.assertEqual(json.loads(result.stdout), [
                    "--profile", str(self.root / folder), "--new-window",
                    "https://example.org/a b?q=x&y=z"])


if __name__ == "__main__":
    unittest.main()
