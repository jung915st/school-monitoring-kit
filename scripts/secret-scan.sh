#!/usr/bin/env bash
# Refuse to publish if anything that looks like a secret or a filled-in site file is tracked.
# Run before every `git push`:  ./scripts/secret-scan.sh
set -euo pipefail
cd "$(dirname "$0")/.."
FAIL=0
files=$(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')
for f in $files; do
  case "$f" in
    site.env|secrets.env|*/.env|.env|*.pem|*.key) echo "TRACKED SECRET FILE: $f"; FAIL=1;;
  esac
done
# value-looking assignments to secret names (placeholders and ${VARS} are fine)
if grep -nIE '(PASSWORD|PASS|SECRET|TOKEN|PSK|COMMUNITY)[A-Z_]*[=:][[:space:]]*"?[A-Za-z0-9+/]{12,}' $files \
   | grep -vE 'CHANGE_ME|\$\{|change-me|example|<'; then
  echo "^^ possible secret values above"; FAIL=1
fi
[ "$FAIL" = 0 ] && echo "secret-scan: clean" || { echo "secret-scan: FAILED"; exit 1; }
