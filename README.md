# School Monitoring Kit

A ready-to-deploy, containerized **switch and network monitoring** stack for a school LAN (SNMP + switch logs), based on the setup running at
LRES (Taichung) since 2025–2026. One folder, one settings file, pinned versions, no secrets.

| Component | What it gives you | Host |
|---|---|---|
| **LibreNMS** 26.9 (+ dispatcher, snmptrapd, MariaDB, Redis, msmtpd) | SNMP polling of switches/firewall/servers, port graphs, alerts by email, weather maps | NMS VM |
| **SmokePing** 2.9 | latency / packet-loss charts for lines and core devices | NMS VM |
| **Graylog** 6.1 (+ OpenSearch 2.18, MongoDB 7) | central switch/firewall syslog: search, streams, link-flap alerts | Log VM |
| **Grafana** 13 | dashboards on Graylog data | Log VM |
| **nginx reverse proxy** + wildcard Let's Encrypt cert | one HTTPS name per console, LAN-only | proxy VM/CT (or NMS VM) |
| *optional* netmon | scheduled checks + status page/email digest | Log VM |

```
   switches / firewall / APs / servers
        │ SNMP (161)        │ syslog (UDP 514)       │ traps (162)
        ▼                   ▼                        ▼
 ┌──────────── NMS VM ───────────┐      ┌────────────── Log VM ──────────────┐
 │ LibreNMS :8000  SmokePing :8081│      │ Graylog :9000  OpenSearch (local)  │
 │ snmptrapd :162                 │      │ Grafana :3000  (netmon optional)   │
 └──────────────▲─────────────────┘      └───────────────▲────────────────────┘
                └──────────── nginx reverse proxy (443) ──┘
                     nms / sp / gl / gfb .<school domain>   (LAN / VPN only)
```

## Profiles
- **standard** (recommended, as at LRES): NMS VM (4 vCPU, 6 GB) + Log VM (8 vCPU, 16 GB, 170 GB data disk) + small proxy.
- **lite** (small schools): everything on one VM (4 vCPU, 16 GB RAM, 120 GB data disk), shorter log retention.

## Quick start
```bash
git clone <this repo> && cd school-monitoring-kit
cp site.env.example site.env && vi site.env      # your school's names, IPs, mail relay
./scripts/gen-secrets.sh                           # random passwords -> secrets.env (git-ignored)
vi secrets.env                                     # set SMTP_PASSWORD
./scripts/render.sh                                # -> out/nms-vm, out/log-vm, out/revproxy
```
Then follow **docs/02-INSTALL.md** host by host.

## Documents
1. [docs/01-PLAN.md](docs/01-PLAN.md) — hosts, names, IP/port plan, firewall rules (fill this in first)
2. [docs/02-INSTALL.md](docs/02-INSTALL.md) — step-by-step installation
3. [docs/03-NETWORK-PREP.md](docs/03-NETWORK-PREP.md) — SNMP/syslog/LLDP/NTP snippets per device type
4. [docs/04-OPERATIONS.md](docs/04-OPERATIONS.md) — backups, upgrades, retention, health checks
5. [docs/05-TROUBLESHOOTING.md](docs/05-TROUBLESHOOTING.md) — known failure modes and fixes

## Rules of the kit
- Never commit `site.env`, `secrets.env` or any `.env`; run `./scripts/secret-scan.sh` before pushing.
- Consoles are **never** published to the internet. Remote access = VPN (e.g. FortiGate IKEv2 dial-up).
- Change versions only via the upgrade procedure in docs/04-OPERATIONS.md.

Kit version: 0.2.0 (2026-10-28). Reference site: LRES.
