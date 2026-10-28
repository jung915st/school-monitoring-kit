# Graylog first setup

1. **Syslog input**: System → Inputs → *Syslog UDP* → Launch new input
   - Global, bind 0.0.0.0, **port 1514** (the host's UDP `SYSLOG_UDP_PORT`, default 514, is mapped to it)
   - Optional *Syslog TCP* on 5140.
   - Tick "Store full message" for FortiGate (key=value parsing later).
2. **Default index set retention** (System → Indices → Default index set → Edit):
   - Data tiering / rotation by time, **min `P${RETENTION_MIN_DAYS}D`, max `P${RETENTION_MAX_DAYS}D`**
     (LRES: P10D / P14D on a 170 GB disk at ~6.5 GB/day). Lite: P5D / P7D.
   - Watch `/srv/data` usage: OpenSearch blocks writes at 95% (flood stage).
3. **FortiGate noise** (large sites): FortiGate local-in deny logs can be >70% of volume.
   - Create index set "fortigate-noise" (P2D / P3D).
   - Create stream "FortiGate local-in deny": `gl2_remote_ip = <FW_IP>` AND `subtype = local` AND `action = deny`,
     *remove matches from Default stream*, index set fortigate-noise.
4. **Streams worth having**: "Network switches" (switch IPs), "Firewall events" (FortiGate type=event),
   "Servers / host checks". Share read-only with a viewer user for colleagues.
5. **Users**: create a personal admin account; keep the built-in `admin` for emergencies.
6. **Time zone**: user profile → Asia/Taipei (stack default is `GRAYLOG_TIMEZONE=${TZ}`).
