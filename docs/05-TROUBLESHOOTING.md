# 05 — Troubleshooting (lessons from LRES)

| Symptom | Cause | Fix |
|---|---|---|
| NMS VM disk 100%, polling stopped | `laravel.log` inside the container layer grew to 33 GB (per-poll debug) | storage-logs host volumes + logrotate (kit default); `LOG_LEVEL=warning` |
| logrotate in /etc/logrotate.d never rotates (Oracle/Rocky) | SELinux blocks `logrotate_t` from user home dirs; `missingok` hides it | per-user crontab logrotate (kit default) |
| Graylog stops indexing, OpenSearch read-only | data disk ≥ 95% flood stage | shorten retention, delete oldest indices, then `PUT _all/_settings {"index.blocks.read_only_allow_delete": null}` |
| Syslog volume huge | FortiGate local-in deny (internet scans, mDNS/LLMNR) | separate stream + 3-day index set (stacks/graylog/SETUP.md) |
| Device in LibreNMS has no Latency tab | SmokePing RRD volume not shared, or target name mismatch | same `data/smokeping/data` mount (kit default); LibreNMS → Settings → External → SmokePing |
| HTTPS console shows the wrong site / cert | request hit the first vhost | default-443.conf (`ssl_reject_handshake on`) — kit default |
| MeshCentral agents disconnect / "proxy" errors | WebSocket headers missing, or proxy IP not trusted | proxy-params + connection-upgrade.conf; `TRUSTED_PROXY`/`TLS_OFFLOAD` = proxy IP |
| Console drops while editing nginx | nginx reload closes long-lived sessions | change nginx in quiet hours; run long jobs detached (`setsid … &> log`) |
| Weather-map edits don't save | LibreNMS editor DataSet is queued | (scripted edits) call `network_nodes.flush()` before `saveMapData()` |
| Port graphs flat, device "up" | SNMP ACL/community mismatch after switch replacement | `snmpwalk -v2c -c <COMM> <ip> sysName` from the NMS VM |
| Switch config lost after power cut | change not saved | `write memory` / `save force` after every change |
| A core link flaps but alerts are noisy | every downstream device alerts | set Device Dependencies (parents) in LibreNMS |
| Port shows LLDP neighbour that isn't cabled there | firewall hard-switch forwards LLDP between member ports | trust traffic counters / FDB over LLDP for that link |
