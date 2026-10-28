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

## Switch-log essentials (the main purpose of this kit)
**Stream "Network switches"**: rule `gl2_remote_ip` matches each switch management IP (or a CIDR via
a regex on `gl2_remote_ip`). Remove matches from the Default stream if you want a separate index set.

Useful searches (save them as Saved Searches):

| What | Query |
|---|---|
| Cisco IOS link up/down | `message:"%LINK-3-UPDOWN" OR message:"%LINEPROTO-5-UPDOWN"` |
| Cisco err-disable / STP | `message:"%PM-4-ERR_DISABLE" OR message:"%SPANTREE"` |
| Aruba/ProCurve link | `message:"is now on-line" OR message:"is now off-line"` |
| Aruba/ProCurve loop / STP | `message:"loop" OR message:"mstp"` |
| HPE Comware link | `message:"PHY_UPDOWN" OR message:"LINK_UPDOWN"` |
| ZyXEL link | `message:"link up" OR message:"link down"` |
| Optics / CRC | `message:"CRC" OR message:"transceiver" OR message:"SFP"` |

**Alert on uplink flaps** (Alerts → Event Definitions → Filter & Aggregation):
- Query: the link query for your vendor AND the uplink port name (e.g. `message:"GigabitEthernet1/0/28"`),
  stream "Network switches".
- Search within the last 10 minutes, run every 5 minutes, aggregate `count() >= 2` (two downs in 10 min = flapping).
- Notification: Email to `ALERT_TO` (Graylog already uses the SMTP relay from site.env — port 587 STARTTLS), or an HTTP notification.
- One event definition per core/edge uplink keeps the alert text precise ("edge720 uplink flapping").
