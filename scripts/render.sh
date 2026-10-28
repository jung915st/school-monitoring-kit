#!/usr/bin/env bash
# Render per-stack .env files and nginx vhosts from site.env (+ profiles/<PROFILE>.env) + secrets.env.
# Output goes to out/<host-role>/ ; nothing outside this folder is touched.
#   ./scripts/render.sh            -> out/nms-vm, out/log-vm, out/revproxy
# Then copy each out/<role>/ folder to its host (docs/02-INSTALL.md).
set -euo pipefail
cd "$(dirname "$0")/.."
command -v envsubst >/dev/null || { echo "envsubst missing (dnf/apt install gettext)"; exit 1; }
[ -f site.env ]    || { echo "site.env missing: cp site.env.example site.env and edit it"; exit 1; }
[ -f secrets.env ] || { echo "secrets.env missing: run ./scripts/gen-secrets.sh"; exit 1; }

set -a
. ./site.env
# shellcheck disable=SC1090
[ -f "profiles/${PROFILE}.env" ] && . "profiles/${PROFILE}.env"
. ./secrets.env
set +a

fail=0
for v in STACK_DIR DOMAIN NMS_VM_IP LOG_VM_IP REVPROXY_IP TZ PUID PGID DATA_ROOT CERT_DIR; do
  [ -n "${!v:-}" ] || { echo "missing $v in site.env"; fail=1; }
done
grep -qE '=CHANGE_ME' secrets.env && { echo "secrets.env still has CHANGE_ME values"; fail=1; }
if [ "$PROFILE" = lite ] && { [ "$NMS_VM_IP" != "$LOG_VM_IP" ] || [ "$NMS_VM_IP" != "$REVPROXY_IP" ]; }; then
  echo "PROFILE=lite needs NMS_VM_IP = LOG_VM_IP = REVPROXY_IP"; fail=1
fi
[ "$fail" = 0 ] || exit 1

rm -rf out && mkdir -p out/nms-vm out/log-vm out/revproxy/sites
umask 077

# ---- NMS VM: librenms (+smokeping) ------------------------------------------
cp -r stacks/librenms out/nms-vm/librenms
cat > out/nms-vm/librenms/.env <<EOF
TZ=$TZ
PUID=$PUID
PGID=$PGID
MGMT_IP=$NMS_VM_IP
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
export STACK_DIR
envsubst < stacks/librenms/librenms.env.tmpl  > out/nms-vm/librenms/librenms.env
envsubst < stacks/librenms/msmtpd.env.tmpl    > out/nms-vm/librenms/msmtpd.env
envsubst '${STACK_DIR}' < stacks/librenms/logrotate.conf.tmpl > out/nms-vm/librenms/logrotate.conf
rm -f out/nms-vm/librenms/*.tmpl

# ---- LOG VM: graylog + opensearch + grafana --------------------------------
cp -r stacks/graylog out/log-vm/graylog
cat > out/log-vm/graylog/.env <<EOF
TZ=$TZ
DATA_ROOT=$DATA_ROOT
GL_HOST=$GL_HOST
GFB_HOST=$GFB_HOST
OPENSEARCH_HEAP=$OPENSEARCH_HEAP
GRAYLOG_JOURNAL_MAX=$GRAYLOG_JOURNAL_MAX
SYSLOG_UDP_PORT=$SYSLOG_UDP_PORT
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_FROM=$SMTP_FROM
GRAYLOG_PASSWORD_SECRET=$GRAYLOG_PASSWORD_SECRET
GRAYLOG_ROOT_PASSWORD_SHA2=$GRAYLOG_ROOT_PASSWORD_SHA2
OPENSEARCH_ADMIN_PASS=$OPENSEARCH_ADMIN_PASS
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
EOF

# ---- Reverse proxy: one vhost per console ----------------------------------
ALLOW_LINES=""
for c in $LAN_CIDRS; do ALLOW_LINES+="    allow $c;"$'\n'; done
export ALLOW_LINES CERT_DIR
vhost() { # name upstream max_body read_timeout
  SERVER_NAME="$1" UPSTREAM="$2" MAX_BODY="$3" READ_TIMEOUT="$4" \
  envsubst '${SERVER_NAME} ${UPSTREAM} ${ALLOW_LINES} ${CERT_DIR} ${MAX_BODY} ${READ_TIMEOUT}' \
    < stacks/reverse-proxy/vhost.conf.tmpl > "out/revproxy/sites/$1.conf"
}
vhost "$NMS_HOST"   "http://$NMS_VM_IP:8000" 64m 300s
vhost "$SMOKE_HOST" "http://$NMS_VM_IP:8081" 1m  60s
vhost "$GL_HOST"    "http://$LOG_VM_IP:9000" 64m 300s
vhost "$GFB_HOST"   "http://$LOG_VM_IP:3000" 16m 300s
cp -r stacks/reverse-proxy/snippets out/revproxy/
cp stacks/reverse-proxy/default-443.conf stacks/reverse-proxy/connection-upgrade.conf out/revproxy/

echo "Rendered for ${SITE_CODE} (profile ${PROFILE}):"
find out -type f | sort | sed 's/^/  /'
