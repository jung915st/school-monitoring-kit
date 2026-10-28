#!/usr/bin/env bash
# Generate random secrets into secrets.env (git-ignored, mode 600). Never overwrites an existing value.
# Usage: ./scripts/gen-secrets.sh            (then add SMTP_PASSWORD by hand)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=secrets.env
umask 077
touch "$OUT"

# finite read (no SIGPIPE under pipefail): keep appending until long enough
rand() { local s=""; while [ "${#s}" -lt "${1:-32}" ]; do s+=$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9'); done; printf '%s' "${s:0:${1:-32}}"; }
have() { grep -q "^$1=" "$OUT"; }
add()  { have "$1" || { echo "$1=$2" >> "$OUT"; echo "  + $1"; }; }

echo "Writing new secrets to $OUT (existing ones are kept):"
add MYSQL_PASSWORD          "$(rand 32)"
add MONGO_PASSWORD          "$(rand 32)"
add GRAYLOG_PASSWORD_SECRET "$(rand 96)"
add OPENSEARCH_ADMIN_PASS   "Os1-$(rand 28)"     # OpenSearch wants upper/lower/digit/symbol
add GRAFANA_ADMIN_PASSWORD  "$(rand 24)"

if ! have GRAYLOG_ROOT_PASSWORD_SHA2; then
  ROOTPW="$(rand 20)"
  echo "GRAYLOG_ROOT_PASSWORD_SHA2=$(printf '%s' "$ROOTPW" | sha256sum | cut -d' ' -f1)" >> "$OUT"
  echo "GRAYLOG_ROOT_PASSWORD_PLAIN=$ROOTPW   # Graylog 'admin' login; move to your password manager, then delete this line" >> "$OUT"
  echo "  + GRAYLOG_ROOT_PASSWORD_SHA2 (plain copy written once, see file)"
fi
have SMTP_PASSWORD || { echo "SMTP_PASSWORD=CHANGE_ME" >> "$OUT"; echo "  ! SMTP_PASSWORD=CHANGE_ME  -> set the mail relay (app) password by hand"; }

chmod 600 "$OUT"
echo "Done. Keep $OUT out of git and back it up somewhere safe (password manager / offline)."
