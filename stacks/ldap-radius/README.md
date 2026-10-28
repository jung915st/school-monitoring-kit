# LDAP + FreeRADIUS for 802.1X Wi-Fi (optional)

Reference implementation at LRES: OpenLDAP 2.6 (Debian slapd) + FreeRADIUS 3.2 in an LXC, PEAP-MSCHAPv2
and EAP-TTLS/PAP, users synced daily from an LDIF in Google Drive, Let's Encrypt cert for EAP/LDAPS.
Source + runbook live in the netmon repo: `deploy/ldap-uos/` and `docs/LDAP-RADIUS.md`.

Adapt for another school:
- Suffix/OU and the user LDIF source.
- RADIUS clients = AP subnets, one shared secret per AP group.
- Certificate name `radius.<domain>` (DNS-01 like stacks/reverse-proxy/ACME.md).
- Guards: minimum user count and maximum deletes per sync, slapcat backup before each apply.
