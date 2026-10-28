#!/usr/bin/env bash
# Run on each Docker host before `docker compose up`. Read-only checks.
#   ./preflight.sh nms     (NMS VM)   |   ./preflight.sh log   (log VM)   |   ./preflight.sh lite
set -uo pipefail
ROLE="${1:-}"; [ -n "$ROLE" ] || { echo "usage: $0 nms|log|lite"; exit 2; }
ok(){ echo "  OK   $*"; }; bad(){ echo "  FAIL $*"; FAIL=1; }; warn(){ echo "  WARN $*"; }
FAIL=0
echo "== preflight ($ROLE) on $(hostname)"

command -v docker >/dev/null && ok "docker $(docker --version | awk '{print $3}')" || bad "docker not installed"
docker compose version >/dev/null 2>&1 && ok "docker compose plugin" || bad "docker compose plugin missing"

mem=$(awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo)
need=6; [ "$ROLE" = log ] && need=15; [ "$ROLE" = lite ] && need=15
[ "$mem" -ge "$need" ] && ok "RAM ${mem} GB (>= ${need})" || bad "RAM ${mem} GB (< ${need} GB)"

if [ "$ROLE" != nms ]; then
  m=$(sysctl -n vm.max_map_count); [ "$m" -ge 262144 ] && ok "vm.max_map_count=$m" || bad "vm.max_map_count=$m (need 262144 for OpenSearch)"
fi

for p in 8000 8081 8443 162 9000 3000 514; do
  ss -lntu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$p$" && warn "port $p already in use"
done

timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes && ok "clock NTP-synchronized" || warn "clock not NTP-synchronized (logs/alerts will have wrong times)"
[ -f /etc/docker/daemon.json ] && grep -q max-size /etc/docker/daemon.json && ok "docker log caps in daemon.json" || warn "no log caps in /etc/docker/daemon.json (see host/daemon.json)"
getenforce 2>/dev/null | grep -q Enforcing && warn "SELinux enforcing: use the per-user logrotate cron (stacks/librenms/logrotate.conf), add :Z to bind mounts if containers get EACCES"

df -h / | awk 'NR==2{print "  INFO / free " $4}'
[ "$FAIL" = 0 ] && echo "== preflight passed" || { echo "== preflight FAILED"; exit 1; }
