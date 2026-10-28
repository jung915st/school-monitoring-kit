# 02 — Install

Order: **render → hosts prep → Log VM → NMS VM → reverse proxy → first logins → add devices.**
`$KIT` = this folder on your admin workstation.

## 0. Render the site files
```bash
cd $KIT
cp site.env.example site.env && vi site.env
./scripts/gen-secrets.sh && vi secrets.env        # set SMTP_PASSWORD
./scripts/render.sh                                # out/nms-vm  out/log-vm  out/revproxy
```

## 1. Prepare each Docker host (NMS VM and Log VM, or the single lite VM)
```bash
# Docker Engine + compose plugin (Oracle/Rocky 9 shown; Debian: see docs.docker.com)
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin gettext
sudo cp host/daemon.json /etc/docker/daemon.json      # log caps (copy from the kit)
sudo systemctl enable --now docker
sudo usermod -aG docker $USER                           # re-login afterwards
sudo timedatectl set-timezone Asia/Taipei && sudo timedatectl set-ntp true
sudo mkdir -p /opt/stacks && sudo chown $USER: /opt/stacks          # = STACK_DIR
```
Log VM (and lite) only:
```bash
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-opensearch.conf && sudo sysctl --system
sudo mkdir -p /srv/data/graylog/{mongo,opensearch,graylog} /srv/data/grafana     # = DATA_ROOT
sudo chown 1000:1000 /srv/data/graylog/opensearch
sudo chown 1100:1100 /srv/data/graylog/graylog
sudo chown 472:472   /srv/data/grafana
```
Run `scripts/preflight.sh nms|log|lite` on the host (copy it over) — fix every FAIL.

## 2. Log VM — Graylog, OpenSearch, Grafana
```bash
scp -r out/log-vm/graylog <user>@<LOG_VM_IP>:/opt/stacks/
ssh <user>@<LOG_VM_IP>
cd /opt/stacks/graylog && chmod 600 .env && docker compose up -d && docker compose ps
```
Then in Graylog (http://<LOG_VM_IP>:9000 until the proxy exists; user `admin`, password = the plain
value gen-secrets.sh printed): follow **stacks/graylog/SETUP.md** (syslog input, index sets, streams).

## 3. NMS VM — LibreNMS + SmokePing, MeshCentral
```bash
scp -r out/nms-vm/* <user>@<NMS_VM_IP>:/opt/stacks/
ssh <user>@<NMS_VM_IP>
cd /opt/stacks/librenms    && chmod 600 .env *.env && mkdir -p data/storage-logs/{web,dispatcher,snmptrapd} && docker compose up -d
cd /opt/stacks/meshcentral && chmod 600 .env && docker compose up -d
# logrotate for LibreNMS Laravel logs (per-user cron; works with SELinux)
mkdir -p ~/logrotate && cp /opt/stacks/librenms/logrotate.conf ~/logrotate/librenms-storage-logs.conf
( crontab -l 2>/dev/null; echo '17 * * * * /usr/sbin/logrotate -s $HOME/logrotate/state $HOME/logrotate/librenms-storage-logs.conf >> $HOME/logrotate/cron.log 2>&1' ) | crontab -
```
- LibreNMS first start takes 1–3 minutes (DB migration). Create the admin user:
  `docker exec -it librenms lnms user:add -r admin -p '<pw>' admin` (or the web installer).
- SmokePing: after first start copy `Targets.example` → `data/smokeping/config/Targets`, edit, `docker restart smokeping`.
- MeshCentral: temporarily set `ALLOW_NEW_ACCOUNTS: "true"`, create the first (admin) account, set back to `"false"`, `docker compose up -d`.

## 4. Reverse proxy
1. Certificate: **stacks/reverse-proxy/ACME.md**.
2. nginx:
```bash
sudo apt -y install nginx            # or dnf
sudo cp -r out/revproxy/snippets /etc/nginx/snippets
sudo cp out/revproxy/connection-upgrade.conf /etc/nginx/conf.d/
sudo cp out/revproxy/default-443.conf /etc/nginx/conf.d/00-default.conf
sudo cp out/revproxy/sites/*.conf /etc/nginx/conf.d/
sudo nginx -t && sudo systemctl reload nginx
```
3. Lock the Docker hosts' console ports to the proxy IP (docs/01-PLAN.md firewall section).
4. Note: reloading nginx can drop long-lived sessions (MeshCentral, PVE console) — do it in quiet hours.

## 5. First configuration
- **LibreNMS**: Settings → SNMP (v2c community or v3), add devices (`lnms device:add <ip>` or UI),
  Alerts → transports: Mail (SMTP host `msmtpd`, port 2500), set device parents (Device Dependencies)
  so one core failure = one alert. Optional: Custom Map (weather map) per building.
- **LibreNMS ↔ SmokePing**: Settings → External → SmokePing: dir `/var/lib/smokeping`, URL `https://sp.<domain>/smokeping/`.
- **Graylog**: see stacks/graylog/SETUP.md.
- **Grafana**: login `admin` / GRAFANA_ADMIN_PASSWORD; datasource "Graylog OpenSearch" is pre-provisioned.
- **Devices**: docs/03-NETWORK-PREP.md.

## 6. Verify
- [ ] https://nms, https://gl, https://gfb, https://sp, https://mesh open from the LAN with a valid certificate
- [ ] A switch shows up in LibreNMS with port graphs after 10 minutes
- [ ] `logger -n <LOG_VM_IP> -P 514 test-from-$(hostname)` appears in Graylog search
- [ ] A test alert mail arrives (LibreNMS → Alerts → Alert transports → Test)
- [ ] `docker compose ps` healthy on both hosts after a reboot
- [ ] Backups configured (docs/04-OPERATIONS.md)
