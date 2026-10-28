# 04 — Operations

## Backups
| What | How | When |
|---|---|---|
| Whole VMs | Proxmox `vzdump` to NAS (zstd, keep-last 1–2) — see host/pve/README.md | weekly (Sun 01:00 / 03:00) |
| LibreNMS DB | `docker exec librenms_db sh -c 'mariadb-dump -u librenms -p"$MYSQL_PASSWORD" librenms' \| gzip > ~/backups/librenms-$(date +%F).sql.gz` | before every upgrade + weekly |
| Graylog | MongoDB (config) via VM backup; log data is disposable by design (retention) | — |
| Secrets | `secrets.env` in the password manager (not on the hosts only) | on change |

## Upgrades (one stack at a time, quiet hours)
1. Read the release notes (LibreNMS, Graylog, OpenSearch especially — major versions migrate data).
2. Snapshot the VM (Proxmox) **and** dump the DB.
3. Change the pinned tag in the kit's `compose.yml`, commit, re-render, copy to the host.
4. `docker compose pull && docker compose up -d && docker compose logs -f --tail=100`.
5. Check the UI and one device/stream; roll back = previous tag + restore snapshot.
Known: LibreNMS 26.x moved API tokens to Sanctum (existing tokens kept working at LRES).
Graylog 6.1 ↔ OpenSearch 2.x and MongoDB 7 is a tested combination — move them together.

## Retention and disk
- Graylog Default index set: P10D / P14D on 170 GB (≈6.5 GB/day at LRES); lite P5D / P7D.
- Alert when `DATA_ROOT` > 80% (cron `df` check → syslog → Graylog alert, or netmon probe).
- LibreNMS Laravel logs: hourly per-user logrotate (installed in 02-INSTALL); docker logs capped by daemon.json.
- LibreNMS RRDs grow with ports: ~1–2 GB per 100 devices.

## Health checks (weekly, 5 minutes)
- LibreNMS: Overview → no devices down that you don't know about; *Poller* page: last poll < 5 min.
- Graylog: System → Overview (no red notifications), Inputs running, journal not growing.
- Disk on both VMs; `docker compose ps` all `Up`.
- Certificate expiry > 30 days (`openssl s_client -connect nms.<domain>:443 </dev/null | openssl x509 -noout -enddate`).

## Accounts and access
- Personal accounts for each admin; disable shared logins. Viewer roles for colleagues.
- Remote access only over VPN (FortiGate IKEv2 dial-up to the reverse proxy on 443 only).
