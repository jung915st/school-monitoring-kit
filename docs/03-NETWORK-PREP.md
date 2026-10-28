# 03 — Prepare network devices

Placeholders: `<NMS>` = NMS_VM_IP, `<LOG>` = LOG_VM_IP, `<COMM>` = SNMP v2c community (read-only),
`<NTP>` = NTP server. Prefer SNMPv3 where the device supports it. **Save the config after every change.**

## Cisco IOS (2960S / 3560E / 3750-X)
```
snmp-server community <COMM> RO SNMP-ACL
ip access-list standard SNMP-ACL
 permit <NMS>
snmp-server host <NMS> version 2c <COMM>
snmp-server enable traps snmp linkdown linkup coldstart
logging host <LOG>
logging trap informational
service timestamps log datetime msec localtime show-timezone
lldp run
ntp server <NTP>
clock timezone CST 8 0
end
write memory
```

## Aruba / HPE ProCurve-ArubaOS-Switch (2930F / 3810M)
```
snmp-server community "<COMM>" operator
snmp-server host <NMS> community "<COMM>" trap-level all
logging <LOG>
logging severity info
lldp run
timesync ntp
ntp unicast
ntp server <NTP> iburst
ntp enable
time timezone 480
write memory
```

## HPE Comware (5130 / 5120)
```
snmp-agent
snmp-agent community read <COMM> acl 2001
acl basic 2001
 rule permit source <NMS> 0
snmp-agent sys-info version v2c v3
snmp-agent target-host trap address udp-domain <NMS> params securityname <COMM> v2c
info-center loghost <LOG> facility local7
lldp global enable
ntp-service enable
ntp-service unicast-server <NTP>
clock timezone CST add 08:00:00
save force
```

## ZyXEL GS1350 / GS1920 / GS2220 (web UI)
- Management → SNMP: version v2c, Get community `<COMM>`, Trap destination `<NMS>`.
- Management → Syslog setup: active, server `<LOG>`, all log types.
- Advanced → LLDP: active on uplink ports.
- Basic → Time: NTP `<NTP>`, UTC+08:00. Save (top-right) after each page.

## FortiGate (FortiOS 7.4)
```
config system snmp sysinfo
    set status enable
end
config system snmp community
    edit 1
        set name "<COMM>"
        config hosts
            edit 1
                set ip <NMS> 255.255.255.255
            next
        end
    next
end
config system interface
    edit "<LAN interface>"
        append allowaccess snmp
    next
end
config log syslogd setting
    set status enable
    set server "<LOG>"
    set port 514
    set format default
end
config system interface
    edit "<LAN interface>"
        set lldp-transmission enable
        set lldp-reception enable
    next
end
```
Allow ICMP + SNMP from `<NMS>` to the other LAN segments in firewall policies.

## Servers (Linux)
- `dnf/apt install net-snmp | snmpd`, `rocommunity <COMM> <NMS>`, restart snmpd; add in LibreNMS.
- rsyslog: `*.* @<LOG>:514` in `/etc/rsyslog.d/90-graylog.conf`.

## After each device
- Add it in LibreNMS (`lnms device:add --v2c -c <COMM> <ip>`), set its **parent** (Device Dependencies).
- Check a syslog line arrives in Graylog (`gl2_remote_ip:<ip>`).
