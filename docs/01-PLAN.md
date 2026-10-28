# 01 — Plan (fill in before installing)

## Hosts
| Role | Profile standard | Profile lite | OS (tested) |
|---|---|---|---|
| NMS VM | 4 vCPU, 6 GB RAM, 40 GB | — | Oracle Linux 9 / Rocky 9 / Debian 12–13 |
| Log VM | 8 vCPU, 16 GB RAM, 40 GB + **170 GB data disk** at `DATA_ROOT` | one VM: 4 vCPU, 16 GB RAM, 40 GB + 120 GB data | same |
| Reverse proxy | 1 vCPU, 1 GB (VM or LXC), or nginx on the NMS VM | on the same VM | Debian 12–13 |

Proxmox is optional; any hypervisor or bare metal works. Give every host a **static** LAN address.

## Names (A records → REVPROXY_IP)
| Name | Service | Upstream |
|---|---|---|
| `nms.<domain>` | LibreNMS | NMS_VM_IP:8000 |
| `sp.<domain>` | SmokePing | NMS_VM_IP:8081 |
| `mesh.<domain>` | MeshCentral | NMS_VM_IP:8443 |
| `gl.<domain>` | Graylog | LOG_VM_IP:9000 |
| `gfb.<domain>` | Grafana | LOG_VM_IP:3000 |

## Ports and firewall rules
| From | To | Port | Why |
|---|---|---|---|
| NMS VM | all managed devices | UDP 161 | SNMP polling |
| NMS VM | all monitored hosts | ICMP | availability + SmokePing |
| devices | NMS VM | UDP/TCP 162 | SNMP traps |
| devices | Log VM | UDP 514 (or TCP 5140) | syslog |
| reverse proxy | NMS VM | TCP 8000, 8081, 8443 | consoles |
| reverse proxy | Log VM | TCP 9000, 3000 | consoles |
| LAN admins / VPN pool | reverse proxy | TCP 443 (80 → redirect) | HTTPS |
| school PCs (agents) | reverse proxy | TCP 443 | MeshCentral agents |
| NMS VM | SMTP relay | TCP 587 | alert mail |
| all hosts | NTP server | UDP 123 | correct timestamps |

On the Docker hosts allow console ports **only from the reverse proxy**
(firewalld rich rule / nftables), e.g. on the Log VM:
```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=<REVPROXY_IP> port port=9000 protocol=tcp accept'
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=<REVPROXY_IP> port port=3000 protocol=tcp accept'
firewall-cmd --permanent --add-port=514/udp && firewall-cmd --reload
```

## Checklist
- [ ] Host IPs chosen and free (check the school IP plan / DHCP scopes)
- [ ] DNS A records and the `_acme-challenge` CNAME requested (stacks/reverse-proxy/ACME.md)
- [ ] Mail relay account for alerts (app password)
- [ ] SNMP v2c community or v3 user decided (same on all devices)
- [ ] Device list with IPs, model, location (becomes LibreNMS devices + netmon inventory)
- [ ] Backup target (NAS share or PVE backup storage)
