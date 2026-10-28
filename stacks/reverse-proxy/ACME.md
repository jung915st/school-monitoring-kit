# Wildcard certificate with acme.sh (DNS-01)

The consoles live on internal names (nms/gl/gfb/sp.<school domain>) that point at a LAN address,
so HTTP-01 cannot work. Use DNS-01. The pattern used at LRES:

1. The school zone (`<school>.tc.edu.tw`) is managed on the city DDNS portal (ddnss.tc.edu.tw).
   Add **once**:
   - A records: `nms`, `gl`, `gfb`, `sp` -> `REVPROXY_IP` (LAN address; only reachable on LAN/VPN).
   - CNAME `_acme-challenge.<school>.tc.edu.tw` -> `_acme-challenge.<your-name>.dedyn.io.`
2. Create a free deSEC account + domain `<your-name>.dedyn.io`, and an API token limited to that domain.
3. On the reverse-proxy host (as root):
   ```bash
   curl https://get.acme.sh | sh -s email=<it-admin-email>
   export DEDYN_TOKEN=<token>            # saved by acme.sh into its account conf
   ~/.acme.sh/acme.sh --issue --dns dns_desec --keylength ec-256 \
       --challenge-alias <your-name>.dedyn.io \
       -d '<school>.tc.edu.tw' -d '*.<school>.tc.edu.tw' --dnssleep 180
   mkdir -p ${CERT_DIR}
   ~/.acme.sh/acme.sh --install-cert -d '<school>.tc.edu.tw' --ecc \
       --fullchain-file ${CERT_DIR}/fullchain.pem --key-file ${CERT_DIR}/key.pem \
       --reloadcmd 'systemctl reload nginx'
   ```
4. acme.sh installs a daily cron and renews about 30 days before expiry.

Notes:
- `--dnssleep 180` avoids an NXDOMAIN race at Let's Encrypt (seen at LRES on the first try).
- Any other acme.sh DNS hook works the same way; set `ACME_DNS_PROVIDER` in site.env for your notes.
