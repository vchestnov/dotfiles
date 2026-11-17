#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_dir" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

repo = Path(sys.argv[1])
helper = repo / "scripts/lib/codex-profile.py"

with tempfile.TemporaryDirectory(prefix="codex-profile-") as temporary:
    root = Path(temporary)
    source = root / "shared defaults.toml"
    home = root / "codex home"
    target = home / "dotfiles.config.toml"
    state = home / ".dotfiles-profile-defaults.toml"
    shared = '''model = "shared-v1"
model_reasoning_effort = "high"
[tui]
status_line_use_colors = true
session_picker_view = "dense"
[tui.keymap.composer]
submit = "f1"
'''
    source.write_text(shared)

    def sync(*flags, success=True):
        result = subprocess.run([sys.executable, str(helper), *flags, str(source), str(target)],
                                capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    def load(path):
        return tomllib.loads(path.read_text())

    # Dry runs must not create a profile, backups, or merge metadata.
    sync("--dry-run")
    assert not home.exists()
    sync()
    assert target.is_file() and not target.is_symlink()
    assert load(target) == tomllib.loads(shared)
    assert load(state) == tomllib.loads(shared)
    assert target.stat().st_mode & 0o777 == 0o600
    assert state.stat().st_mode & 0o777 == 0o600

    # Simulate future CLI writes, including nested preferences and project trust.
    contents = target.read_text().replace('"shared-v1"', '"local-model"')
    contents = contents.replace('"high"', '"local-reasoning"')
    contents += '\n[projects."/work/new-project"]\ntrust_level = "trusted"\n'
    target.write_text(contents)
    before = target.read_bytes()
    sync()
    assert target.read_bytes() == before
    assert not list(home.glob("*.bak.*"))
    assert source.read_text() == shared

    # Shared updates flow through untouched keys; local overrides and trust stay.
    source.write_text(shared.replace('"shared-v1"', '"shared-v2"')
                      .replace('"high"', '"medium"')
                      .replace('"dense"', '"compact"')
                      .replace('submit = "f1"', 'submit = "f2"'))
    sync()
    config = load(target)
    assert config["model"] == "local-model"
    assert config["model_reasoning_effort"] == "local-reasoning"
    assert config["tui"]["session_picker_view"] == "compact"
    assert config["tui"]["keymap"]["composer"]["submit"] == "f2"
    assert config["projects"]["/work/new-project"]["trust_level"] == "trusted"
    backups = list(home.glob("*.bak.*"))
    assert len(backups) == 1 and backups[0].read_bytes() == before
    saved = {path.name: path.read_bytes() for path in home.iterdir()}
    sync()
    assert saved == {path.name: path.read_bytes() for path in home.iterdir()}

    # Removing shared settings removes unchanged defaults, retaining overrides.
    source.write_text('model = "shared-v3"\n')
    sync()
    config = load(target)
    assert "tui" not in config
    assert config["model_reasoning_effort"] == "local-reasoning"
    assert config["projects"]["/work/new-project"]["trust_level"] == "trusted"

    # Local deletions are also overrides, even if shared defaults later change.
    source.write_text('model = "shared-v3"\nmodel_reasoning_effort = "low"\n')
    target.write_text(target.read_text().replace('"model" = "local-model"\n', ''))
    sync()
    assert "model" not in load(target)

    # Migrate a legacy symlink without writing through it or distributing trust.
    legacy_source = root / "legacy.toml"
    legacy_source.write_text(shared + '\n[projects."/work/amflow"]\ntrust_level = "trusted"\n')
    legacy_target = root / "legacy home/dotfiles.config.toml"
    legacy_target.parent.mkdir()
    legacy_target.symlink_to(legacy_source)
    source, target, state = legacy_source, legacy_target, legacy_target.parent / ".dotfiles-profile-defaults.toml"
    legacy_bytes = source.read_bytes()
    sync("--dry-run")
    assert target.is_symlink() and not state.exists()
    sync()
    assert not target.is_symlink() and source.read_bytes() == legacy_bytes
    assert load(target)["projects"]["/work/amflow"]["trust_level"] == "trusted"
    assert "projects" not in load(state)
    backup = next(target.parent.glob("*.bak.*"))
    assert not backup.is_symlink() and backup.read_bytes() == legacy_bytes
    source.write_text(shared)
    sync()
    assert load(target)["projects"]["/work/amflow"]["trust_level"] == "trusted"
    assert backup.read_bytes() == legacy_bytes
    fresh = root / "fresh home/dotfiles.config.toml"
    target = fresh
    source.write_bytes(legacy_bytes)
    sync()
    assert "projects" not in load(target)

    # Invalid TOML must fail without replacing existing settings or backups.
    target.write_text("malformed = [\n")
    before = target.read_bytes()
    saved = set(target.parent.iterdir())
    sync(success=False)
    assert target.read_bytes() == before and set(target.parent.iterdir()) == saved

    # Preserve TOML types in local settings when a merge rewrites the document.
    source.write_text(shared)
    target = root / "typed home/dotfiles.config.toml"
    target.parent.mkdir()
    target.write_text('''[custom]
when = 2026-11-16T10:20:30Z
day = 2026-11-16
clock = 10:20:30
items = [{name = "a.b", flags = [true, false]}, {name = "second", value = 1.5}]
text = "line\\nquote\\\""
emoji = "🔬"
delete = "\\u007f"
''')
    custom = load(target)["custom"]
    sync()
    assert load(target)["custom"] == custom

    # Refuse an accidental in-place merge into the tracked template.
    target = source
    before = source.read_bytes()
    sync(success=False)
    assert source.read_bytes() == before

print("Codex local profile checks passed")
PY
