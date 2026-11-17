#!/usr/bin/env python3
"""Sync shared Codex defaults into a writable, host-local profile."""

import argparse
import copy
import datetime
import json
import os
from pathlib import Path
import sys
import tempfile

try:
    import tomllib
except ModuleNotFoundError:
    sys.exit("Codex profile sync requires Python 3.11 or newer.")


MISSING = object()


def read_config(path):
    if not path.exists():
        if path.is_symlink():
            raise ValueError(f"Broken configuration symlink: {path}")
        return None, {}
    contents = path.read_bytes()
    return contents, tomllib.loads(contents.decode("utf-8"))


def shared_defaults(config):
    # Older symlinked profiles may already contain trust decisions. Read them
    # from the local profile during migration, never distribute them as defaults.
    return {key: value for key, value in config.items() if key != "projects"}


def merge_defaults(local, previous, shared, path=()):
    """Advance unchanged defaults, preserving local overrides and deletions."""
    merged = copy.deepcopy(local)
    for key in dict.fromkeys([*previous, *shared]):
        current = local.get(key, MISSING)
        old = previous.get(key, MISSING)
        new = shared.get(key, MISSING)
        if isinstance(current, dict) and (old is MISSING or isinstance(old, dict)) \
                and (new is MISSING or isinstance(new, dict)):
            table = merge_defaults(current, {} if old is MISSING else old,
                                   {} if new is MISSING else new, (*path, key))
            if table or new is not MISSING:
                merged[key] = table
            else:
                merged.pop(key, None)
        elif old is not MISSING and type(current) is type(old) and current == old:
            if new is MISSING:
                merged.pop(key, None)
            else:
                merged[key] = copy.deepcopy(new)
        elif current is MISSING:
            if old is MISSING and new is not MISSING:
                merged[key] = copy.deepcopy(new)
        elif new is not MISSING and current != new and old != new:
            print(f"Keeping local Codex override: {'.'.join((*path, key))}")
    return merged


def toml_value(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False).replace("\x7f", "\\u007f")
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, (datetime.datetime, datetime.date, datetime.time)):
        return value.isoformat()
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{toml_value(key)} = {toml_value(item)}"
                                 for key, item in value.items()) + " }"
    raise ValueError(f"Unsupported TOML value type: {type(value).__name__}")


def serialize(config, header):
    lines = [header]

    def table(values, path=()):
        if path:
            lines.extend(["", "[" + ".".join(toml_value(key) for key in path) + "]"])
        for key, value in values.items():
            if not isinstance(value, dict):
                lines.append(f"{toml_value(key)} = {toml_value(value)}")
        for key, value in values.items():
            if isinstance(value, dict):
                table(value, (*path, key))

    table(config)
    return ("\n".join(lines) + "\n").encode("utf-8")


def atomic_write(path, contents):
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(contents)
        # Replace the directory entry itself, never write through a symlink.
        os.replace(temporary, path)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


def synchronize(source, target, dry_run):
    if source.absolute() == target.absolute() or (
            target.exists() and not target.is_symlink() and source.samefile(target)):
        raise ValueError("The local Codex profile must differ from the shared template.")
    source_bytes, template = read_config(source)
    if source_bytes is None:
        raise ValueError(f"Shared Codex template not found: {source}")
    if "projects" in template:
        print("Ignoring project trust in the shared template; retaining local trust only.")
    shared = shared_defaults(template)
    original, local = read_config(target)
    state_path = target.with_name(".dotfiles-profile-defaults.toml")
    state_bytes, previous = read_config(state_path)
    merged = merge_defaults(local, shared_defaults(previous), shared)
    replace_profile = target.is_symlink() or original is None or merged != local
    replace_state = state_path.is_symlink() or state_bytes is None or previous != shared
    profile_contents = serialize(merged, "# Local Codex profile; shared defaults managed by makesymlinks.sh.")
    state_contents = serialize(shared, "# Last shared Codex defaults; host-local merge state.")
    tomllib.loads(profile_contents.decode("utf-8"))
    tomllib.loads(state_contents.decode("utf-8"))

    if dry_run:
        print(f"[dry-run] Would sync Codex profile: {source} -> {target}")
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    # Refuse to overwrite settings saved while the merge was being prepared.
    if read_config(target)[0] != original or read_config(state_path)[0] != state_bytes:
        raise ValueError("Codex settings changed during sync; rerun setup.")
    if replace_profile:
        if original is not None:
            stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            descriptor, backup = tempfile.mkstemp(prefix=f"{target.name}.bak.{stamp}.",
                                                  dir=target.parent)
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(original)
            print(f"Backed up Codex profile: {backup}")
        atomic_write(target, profile_contents)
        print(f"Synced local Codex profile: {source} -> {target}")
    else:
        print(f"Local Codex profile already current: {target}")
    if replace_state:
        atomic_write(state_path, state_contents)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()
    try:
        synchronize(args.source, args.target, args.dry_run)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Codex profile sync failed: {error}\n")


if __name__ == "__main__":
    main()
