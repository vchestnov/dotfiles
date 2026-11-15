#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export VPN_TEST_DIR=$test_dir
mkdir "$test_dir/bin"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cat > "$test_dir/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${VPN_TEST_NM_FAIL:-0} == 0 ]] || exit 9
if [[ $1 == --get-values ]]; then
    case $2 in
        connection.type) printf '%s\n' "${VPN_TEST_TYPE:-wireguard}" ;;
        GENERAL.STATE) cat "$VPN_TEST_DIR/state" ;;
        GENERAL.DEVICES) printf 'wg-redshield\n' ;;
        *) exit 2 ;;
    esac
elif [[ $1 == --wait && $3 == connection ]]; then
    printf '%s\n' "$4" >> "$VPN_TEST_DIR/actions"
    case $4 in
        up) printf 'activated\n' > "$VPN_TEST_DIR/state" ;;
        down) : > "$VPN_TEST_DIR/state" ;;
        *) exit 2 ;;
    esac
else
    exit 2
fi
EOF
cat > "$test_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$@" >> "$VPN_TEST_DIR/requests"
[[ $1 != "--ipv${VPN_TEST_CURL_FAIL:-0}" ]] || exit 7
printf 'ip=198.51.100.1\nloc=NL\n'
EOF
cat > "$test_dir/bin/resolvectl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$VPN_TEST_DIR/resolver"
EOF
cat > "$test_dir/bin/ip" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $1 == "-${VPN_TEST_BAD_ROUTE:-0}" ]]; then
    printf '%s dev wifi src 192.0.2.1\n' "$4"
else
    printf '%s dev wg-redshield table 50000 src 192.0.2.2\n' "$4"
fi
EOF
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH"
vpn="$repo_dir/scripts/vpn"
: > "$test_dir/state"
"$vpn" --help > "$test_dir/output"
if "$vpn" surprise > "$test_dir/output" 2>&1; then fail 'unknown command accepted'; fi
if "$vpn" on extra > "$test_dir/output" 2>&1; then fail 'extra argument accepted'; fi
"$vpn" off > "$test_dir/output"
[[ ! -f $test_dir/actions ]] || fail 'off changed an inactive connection'
if "$vpn" check > "$test_dir/output" 2>&1; then fail 'inactive VPN passed check'; fi
[[ ! -f $test_dir/requests ]] || fail 'inactive check made network requests'
"$vpn" toggle > "$test_dir/output"
[[ $("$vpn" --status) == VPN:on ]] || fail 'toggle did not activate'
"$vpn" status > "$test_dir/output"
rg -q 'unverified' "$test_dir/output" || fail 'activation was reported as verified'
"$vpn" on > "$test_dir/output"
[[ $(wc -l < "$test_dir/actions") == 1 ]] || fail 'on reactivated an active profile'
"$vpn" check > "$test_dir/output"
for token in --ipv4 --ipv6 --interface wg-redshield --noproxy '*'; do
    rg -F -x -q -- "$token" "$test_dir/requests" || fail "missing traffic isolation: $token"
done
rg -q '^domain wg-redshield$' "$test_dir/resolver" || fail 'DNS routing was not reported'
VPN_TEST_CURL_FAIL=6 "$vpn" check > "$test_dir/output" 2>&1
rg -q 'IPv6 internet unavailable' "$test_dir/output" || fail 'unavailable IPv6 was not reported'
if VPN_TEST_CURL_FAIL=4 "$vpn" check > "$test_dir/output" 2>&1; then fail 'broken IPv4 passed'; fi
for family in 4 6; do
    : > "$test_dir/requests"
    if VPN_TEST_BAD_ROUTE=$family "$vpn" check > "$test_dir/output" 2>&1; then
        fail "IPv$family bypass was not rejected"
    fi
    [[ ! -s $test_dir/requests ]] || fail 'a routing bypass triggered a network request'
done
"$vpn" toggle > "$test_dir/output"
[[ $("$vpn" --status) == VPN:off ]] || fail 'toggle did not deactivate'
if VPN_TEST_NM_FAIL=1 "$vpn" on > "$test_dir/output" 2>&1; then fail 'NM failure ignored'; fi
if VPN_TEST_TYPE=wifi "$vpn" off > "$test_dir/output" 2>&1; then fail 'non-WireGuard profile accepted'; fi

# Use harmless generated keys and libnm's real parser without accessing D-Bus.
TEST_REPO="$repo_dir" /usr/bin/python3 - <<'PY'
import base64
import os
from pathlib import Path
import stat
import subprocess

root = Path(os.environ['VPN_TEST_DIR'])
script = Path(os.environ['TEST_REPO']) / 'scripts/lib/redshield-import.py'
private = base64.b64encode(bytes([1]) * 32).decode()
public = base64.b64encode(bytes([2]) * 32).decode()
config = f'''[Interface]
Address = 10.0.0.2/32, fd00::2/128
PrivateKey = {private}
DNS = 10.0.0.1
[Peer]
PublicKey = {public}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = vpn.example.org:51820
'''
cases = {
    'valid': (config, True),
    'ipv4-only': (config.replace('0.0.0.0/0, ::/0', '0.0.0.0/0'), False),
    'missing-dns': (config.replace('DNS = 10.0.0.1\n', ''), False),
    'invalid-key': (config.replace(private, 'SECRET-invalid-private-key'), False),
    'hooks': (config.replace('[Peer]', 'PostUp = echo SECRET-hook\n[Peer]'), False),
    'custom-table': (config.replace('[Peer]', 'Table = off\n[Peer]'), False),
}
for name, (contents, success) in cases.items():
    path = root / (name + '.conf')
    path.write_text(contents)
    path.chmod(0o644)
    result = subprocess.run(['/usr/bin/python3', str(script), '--dry-run', str(path)],
                            capture_output=True, text=True)
    assert (result.returncode == 0) == success, (name, result.stdout, result.stderr)
    output = result.stdout + result.stderr
    assert private not in output and 'SECRET-' not in output, name
    assert stat.S_IMODE(path.stat().st_mode) == 0o644, 'dry run changed permissions'
print('VPN importer validation passed')
PY
printf 'VPN helper checks passed\n'
