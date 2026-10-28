# netmon (optional add-on)

netmon is the scheduled check runner + LAN status page used at LRES (repo: `jung915st/netmon`, private).
It reads an `inventory.yaml` (devices, uplinks, services) and generates probes: ping/TCP/DNS/HTTP checks,
LibreNMS port/optics checks via API, Graylog syslog queries (uplink flaps), disk checks; results go to a
LAN status page (nmc) and an email/Google Sheets digest (Apps Script).

To use it at another school:
1. Ask the LRES maintainer for access, clone it on the Log VM under `~/stacks/netmon`.
2. Replace `inventory/inventory.yaml` with your devices (`inventory.example.yaml` pattern: id, ip, role,
   location, uplink {device, port, media}, services).
3. Create `.env` with a LibreNMS API token (read-only user) and a Graylog read-only user/token.
4. `tools/run-gen.sh test` → review probes → `docker compose up -d --build`.
5. Apps Script digest is optional (needs a Google account + clasp).

Not required for the core kit — LibreNMS alerts + Graylog alerts cover the basics.
