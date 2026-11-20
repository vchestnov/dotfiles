#!/usr/bin/env python3
"""Offline API and launcher checks; never access a real Codex login or session."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


script = Path(__file__).resolve().parents[1] / "scripts/codex-resume"
first_id = "00000000-0000-7000-8000-000000000001"
second_id = "00000000-0000-7000-8000-000000000002"


class CodexResumeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="codex-resume-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.project = self.root / "project's code; $(touch forbidden)"
        self.project.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.session = {
            "id": first_id, "name": "Math\twork\n\x1b[31mλ", "preview": "",
            "updatedAt": 200, "cwd": str(self.project), "path": "/fixture/rollout.jsonl",
        }
        self.pages = [{"data": [self.session], "nextCursor": None}]
        self.env = dict(os.environ, HOME=str(self.home), CODEX_HOME=str(self.home / ".codex"),
                        PATH=f"{self.bin}:/usr/bin:/bin", RESUME_TEST_ROOT=str(self.root))
        self.write_program("codex", r'''
import base64, hashlib, json, os, pathlib, struct, sys
root = pathlib.Path(os.environ["RESUME_TEST_ROOT"])
if sys.argv[1:] != ["app-server", "proxy"]:
    (root / "launch.json").write_text(json.dumps(sys.argv[1:]))
    sys.exit(0)
mode = os.environ.get("RESUME_TEST_MODE", "")
if mode == "closed":
    sys.exit(1)
pages = json.loads((root / "pages.json").read_text())
index = 0
reader, writer = sys.stdin.buffer, sys.stdout.buffer
assert reader.readline() == b"GET / HTTP/1.1\r\n"
headers = {}
while True:
    line = reader.readline()
    if line == b"\r\n": break
    name, value = line.decode().split(":", 1)
    headers[name.lower()] = value.strip()
assert headers["upgrade"] == "websocket"
accept = base64.b64encode(hashlib.sha1((headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
if mode == "bad-handshake": accept = "invalid"
writer.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n").encode())
writer.flush()

def receive():
    while True:
        header = reader.read(2)
        if not header: return None
        first, second = header
        assert first & 0x80 and second & 0x80, "client frames must be final and masked"
        size = second & 0x7f
        if size == 126: size = int.from_bytes(reader.read(2), "big")
        elif size == 127: size = int.from_bytes(reader.read(8), "big")
        mask = reader.read(4)
        payload = bytes(value ^ mask[i % 4] for i, value in enumerate(reader.read(size)))
        if first & 0x0f == 8: return None
        if first & 0x0f == 10: continue
        assert first & 0x0f == 1
        return json.loads(payload)

def frame(payload, opcode=1, final=True):
    size = len(payload)
    if size < 126: length = bytes([size])
    elif size < 65536: length = b"\x7e" + struct.pack("!H", size)
    else: length = b"\x7f" + struct.pack("!Q", size)
    writer.write(bytes([(0x80 if final else 0) | opcode]) + length + payload)
    writer.flush()

def send(message):
    payload = json.dumps(message, ensure_ascii=False).encode()
    if mode == "fragments":
        middle = len(payload) // 2
        frame(payload[:middle], final=False)
        frame(b"ping", opcode=9)
        frame(payload[middle:], opcode=0)
    else:
        frame(payload)

while True:
    message = receive()
    if message is None: break
    with (root / "requests.jsonl").open("a") as log:
        log.write(json.dumps(message) + "\n")
    if "id" not in message or "method" not in message:
        continue
    if message["method"] == "initialize":
        result = {"userAgent": "fixture"}
    else:
        assert message["method"] == "thread/list", message
        if mode == "rpc-error":
            send({"id": message["id"], "error": {"code": -1, "message": "fixture listing error"}})
            continue
        if mode == "approval-request":
            send({"id": "approval", "method": "item/commandExecution/requestApproval", "params": {}})
        result = pages[min(index, len(pages) - 1)]
        index += 1
    send({"method": "fixture/notification", "params": {}})
    send({"id": message["id"], "result": result})
''')
        self.write_program("fzf", r'''
import json, os, pathlib, sys
root = pathlib.Path(os.environ["RESUME_TEST_ROOT"])
rows = sys.stdin.read()
(root / "picker.txt").write_text(rows)
(root / "picker-args.json").write_text(json.dumps(sys.argv[1:]))
assert "FZF_DEFAULT_OPTS" not in os.environ
assert "FZF_DEFAULT_OPTS_FILE" not in os.environ
mode = os.environ.get("RESUME_TEST_PICKER", "")
if mode == "cancel": sys.exit(130)
if mode == "no-match": sys.exit(1)
if mode == "error": sys.exit(2)
if mode == "unknown": print("unknown\tfabricated"); sys.exit(0)
print(rows.splitlines()[0])
''')

    def write_program(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env python3\n" + body)
        path.chmod(0o755)

    def run_helper(self, *args, **environment):
        (self.root / "pages.json").write_text(json.dumps(self.pages))
        return subprocess.run([str(script), *args], cwd=self.project,
                              env=dict(self.env, **environment), text=True,
                              capture_output=True, timeout=10)

    def requests(self):
        return [json.loads(line) for line in (self.root / "requests.jsonl").read_text().splitlines()]

    def test_listing_requests_all_accounts_and_providers_for_current_directory(self):
        result = self.run_helper("--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(first_id, result.stdout)
        self.assertEqual(len(result.stdout.splitlines()), 1)
        self.assertNotIn("\x1b", result.stdout)
        listing = [r for r in self.requests() if r["method"] == "thread/list"][0]["params"]
        self.assertIs(listing["currentAccountOnly"], False)
        self.assertEqual(listing["modelProviders"], [])
        self.assertEqual(listing["cwd"], str(self.project))
        self.assertIs(listing["archived"], False)
        self.assertFalse((self.root / "launch.json").exists())
        self.assertEqual(list(self.home.iterdir()), [])

    def test_all_directories_and_pagination_keep_newest_first(self):
        later = dict(self.session, id=second_id, updatedAt=300, name="Other session")
        self.pages = [{"data": [self.session], "nextCursor": "next-page"},
                      {"data": [later], "nextCursor": None}]
        result = self.run_helper("--list", "--all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.startswith(second_id))
        listings = [r["params"] for r in self.requests() if r["method"] == "thread/list"]
        self.assertEqual([r["cursor"] for r in listings], [None, "next-page"])
        self.assertTrue(all(r["cwd"] is None and not r["currentAccountOnly"] for r in listings))

    def test_selection_preserves_literal_paths_and_uses_shared_profile(self):
        result = self.run_helper("--query", "math λ", FZF_DEFAULT_OPTS="--multi --print-query",
                                 FZF_DEFAULT_OPTS_FILE="/unused/options")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.root / "launch.json").read_text()), [
            "resume", first_id, "--cd=" + str(self.project), "--profile=dotfiles",
        ])
        self.assertIn("--query=math λ", json.loads((self.root / "picker-args.json").read_text()))
        self.assertFalse((self.project / "forbidden").exists())

    def test_dry_run_and_custom_or_base_profile(self):
        for options, ending in [(["--profile", "personal"], ["--profile=personal"]),
                                (["--no-profile"], [])]:
            with self.subTest(options=options):
                result = self.run_helper("--dry-run", *options)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(shlex.split(result.stdout), [str(self.bin / "codex"),
                    "resume", first_id, "--cd=" + str(self.project), *ending])
                self.assertFalse((self.root / "launch.json").exists())

    def test_cancel_and_no_match_do_not_launch(self):
        for mode in ["cancel", "no-match"]:
            result = self.run_helper(RESUME_TEST_PICKER=mode)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((self.root / "launch.json").exists())

    def test_listing_does_not_require_fzf(self):
        (self.bin / "fzf").unlink()
        result = self.run_helper("--list")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_daemon_and_api_errors_are_actionable(self):
        for mode, message in [("closed", "codex app-server daemon start"),
                              ("rpc-error", "fixture listing error")]:
            result = self.run_helper("--list", RESUME_TEST_MODE=mode)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(message, result.stderr)
            self.assertNotIn("Traceback", result.stderr)

    def test_repeated_cursor_is_rejected(self):
        self.pages = [{"data": [self.session], "nextCursor": "same"}]
        result = self.run_helper("--list")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("repeated pagination cursor", result.stderr)

    def test_websocket_fragments_ping_and_large_responses(self):
        for size in [200, 70000]:
            with self.subTest(size=size):
                self.pages = [{"data": [dict(self.session, name="λ" * size)], "nextCursor": None}]
                result = self.run_helper("--list", RESUME_TEST_MODE="fragments")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(first_id, result.stdout)

    def test_invalid_websocket_handshake_is_rejected(self):
        result = self.run_helper("--list", RESUME_TEST_MODE="bad-handshake")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not accept a WebSocket", result.stderr)

    def test_listing_never_approves_server_requests(self):
        result = self.run_helper("--list", RESUME_TEST_MODE="approval-request")
        self.assertEqual(result.returncode, 0, result.stderr)
        replies = [r for r in self.requests() if r.get("id") == "approval"]
        self.assertEqual(len(replies), 1)
        self.assertEqual(replies[0]["error"]["code"], -32601)
        self.assertNotIn("result", replies[0])

    def test_symlinked_launcher_works_from_another_directory(self):
        launcher = self.bin / "codex-resume"
        launcher.symlink_to(script)
        (self.root / "pages.json").write_text(json.dumps(self.pages))
        result = subprocess.run([str(launcher), "--list"], cwd=self.project,
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(first_id, result.stdout)

    def test_empty_history_and_invalid_selection_do_not_launch(self):
        self.pages = [{"data": [], "nextCursor": None}]
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("try --all", result.stderr)
        self.pages = [{"data": [self.session], "nextCursor": None}]
        for mode in ["unknown", "error"]:
            result = self.run_helper(RESUME_TEST_PICKER=mode)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.root / "launch.json").exists())


if __name__ == "__main__":
    unittest.main()
