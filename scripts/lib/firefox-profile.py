#!/usr/bin/python3
"""Launch a Firefox profile by display name without storing host-local paths."""

import configparser
from contextlib import closing
import os
from pathlib import Path
import sqlite3
import sys


def profile_roots():
    override = os.environ.get("FIREFOX_PROFILE_ROOT")
    if override:
        return [Path(override).expanduser()]
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    return [home / "snap/firefox/common/.mozilla/firefox",
            config / "mozilla/firefox", home / ".mozilla/firefox"]


def find_profile(name, roots):
    matches = set()
    for root in roots:
        root = root.resolve()
        paths = set()
        # The new profile manager keeps display names in SQLite, separately
        # from profiles.ini. Folder names can retain an earlier profile name.
        for database in sorted((root / "Profile Groups").glob("*.sqlite")):
            with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro",
                                         uri=True)) as connection:
                paths.update(row[0] for row in connection.execute(
                    "SELECT path FROM Profiles WHERE name = ?", (name,)))

        if not paths:
            profiles = configparser.RawConfigParser()
            profiles.read(root / "profiles.ini")
            for section in profiles.sections():
                if (section.startswith("Profile")
                        and profiles.get(section, "Name", fallback=None) == name):
                    path = Path(profiles.get(section, "Path"))
                    if profiles.getboolean(section, "IsRelative", fallback=True):
                        path = root / path
                    paths.add(str(path))

        matches.update((root / path).resolve() for path in paths)

    if not matches:
        raise ValueError(f"profile {name!r} not found; check its name in Firefox")
    if len(matches) > 1:
        raise ValueError(f"multiple profiles named {name!r}; set FIREFOX_PROFILE_ROOT "
                         "to the Firefox directory containing the intended profile")
    profile = matches.pop()
    if not profile.is_dir():
        raise ValueError(f"profile directory is missing: {profile}")
    return profile


def main():
    if len(sys.argv) < 2:
        raise ValueError("expected a profile name followed by optional Firefox arguments")
    profile = find_profile(sys.argv[1], profile_roots())
    os.execvp("firefox", ["firefox", "--profile", str(profile), *sys.argv[2:]])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, sqlite3.Error, configparser.Error) as error:
        sys.exit(f"firefox-profile: {error}")
