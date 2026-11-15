#!/usr/bin/python3
"""Save a full-tunnel Redshield profile without ever autoactivating it."""

import argparse
import os
from pathlib import Path
import stat
import sys

import gi

gi.require_version("NM", "1.0")
from gi.repository import GLib, NM


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    source = args.config.expanduser().absolute()
    info = source.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError("Use a regular configuration file owned by the current user")
    # NetworkManager ignores wg-quick hooks. Refuse rather than silently lose
    # firewall or routing instructions embedded in an imported configuration.
    for line in source.read_text().splitlines():
        key, separator, value = line.partition("=")
        if separator and key.strip() in {"PreUp", "PostUp", "PreDown", "PostDown"}:
            raise ValueError("wg-quick hooks require separate setup; import refused")
        if separator and key.strip() == "Table" and value.strip() != "auto":
            raise ValueError("Custom routing tables require separate setup; import refused")
    try:
        profile = NM.conn_wireguard_import(str(source))
    except GLib.Error:
        raise ValueError("Invalid WireGuard configuration; details hidden to protect keys") from None
    wireguard = profile.get_setting(NM.SettingWireGuard)
    allowed = set()
    for index in range(wireguard.get_peers_len()):
        peer = wireguard.get_peer(index)
        allowed.update(peer.get_allowed_ip(i) for i in range(peer.get_allowed_ips_len()))
    if not {"0.0.0.0/0", "::/0"}.issubset(allowed):
        raise ValueError("Expected full-tunnel routes for both IPv4 and IPv6")
    settings = (profile.get_setting_ip4_config(), profile.get_setting_ip6_config())
    if not any(setting.get_num_dns() for setting in settings if setting):
        raise ValueError("The configuration must specify VPN DNS servers")
    connection = profile.get_setting_connection()
    connection.props.id = "redshield"
    connection.props.interface_name = "wg-redshield"
    connection.props.autoconnect = False
    for setting in settings:
        if setting is None or not setting.get_num_addresses():
            raise ValueError("Expected tunnel addresses for both IPv4 and IPv6")
        setting.props.method = "manual"
        setting.props.never_default = False
        setting.props.dns_priority = 50
        setting.clear_dns_searches()
        setting.add_dns_search("~.")
    profile.verify()
    if args.dry_run:
        print("Valid full-tunnel profile: redshield / wg-redshield; autoconnect disabled")
        print("VPN DNS uses ~. and priority 50; local DNS remains available")
        return
    client = NM.Client.new(None)
    if any(item.get_id() == "redshield" or item.get_interface_name() == "wg-redshield"
           for item in client.get_connections()):
        raise ValueError("A redshield profile/interface is already configured; refusing to overwrite")
    os.chmod(source, 0o600)
    loop = GLib.MainLoop()
    errors = []

    def finished(client, result, _data):
        try:
            saved = client.add_connection_finish(result)
            print("Saved profile:", saved.get_id(), saved.get_uuid())
            print("Autoconnect disabled; VPN remains off. Source permissions set to 0600.")
        except GLib.Error:
            errors.append("NetworkManager could not save the profile; check service and permissions")
        finally:
            loop.quit()

    client.add_connection_async(profile, True, None, finished, None)
    loop.run()
    if errors:
        raise ValueError(errors[0])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, GLib.Error) as error:
        # OSError/GLib.Error can contain paths or parse details; keep those out
        # of terminal logs. Our explicit ValueError messages contain no keys.
        message = str(error) if isinstance(error, ValueError) else "Import failed; check the file and NetworkManager access"
        sys.exit("redshield-import: " + message)
