#!/usr/bin/env bash
# NEXZ hair clip restock monitor.
# Polls the 7 non-FOX2Y NEXZ hair clips on jypj-store.com every 10s via Shopify's
# per-product .js endpoint (real "available" flag). Sends an email and exits the
# instant any one becomes available.
#
# Exit codes: 0 = restock found (email sent) | 7 = hit safety cap with no restock.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRIPT_DIR/restock.log"
MAX_ITERS=4320   # ~12h at 10s

# Shopify product handle -> display name. FOX2Y (nx26-lt0-0038) is intentionally excluded.
declare -A NAMES=(
  [nx26-lt0-0037]="YUTiE"
  [nx26-lt0-0031]="PPOMOYA"
  [nx26-lt0-0036]="HYUROMI"
  [nx26-lt0-0035]="SEIDEE"
  [nx26-lt0-0034]="GEONSKY"
  [nx26-lt0-0033]="HARUBEAR"
  [nx26-lt0-0032]="JELLY-YU"
)

for ((i=1; i<=MAX_ITERS; i++)); do
  found=""
  for h in "${!NAMES[@]}"; do
    avail=$(curl -s --max-time 8 "https://jypj-store.com/products/$h.js" -A "Mozilla/5.0" \
            | grep -oE '"available":(true|false)' | head -1)
    if [ "$avail" = '"available":true' ]; then
      found="$found ${NAMES[$h]}(https://jypj-store.com/en/products/$h)"
    fi
  done
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  if [ -n "$found" ]; then
    echo "[$ts] RESTOCK:$found"
    echo "[$ts] RESTOCK:$found" >> "$LOG"
    python3 "$SCRIPT_DIR/send_mail.py" "🔔 NEXZ hair clip RESTOCK!" \
"One or more NEXZ hair clips are back IN STOCK:
$found

Detected at $ts. Go grab it before it sells out again!" \
      >> "$LOG" 2>&1
    exit 0
  fi
  echo "[$ts] check #$i: all 7 still sold out" >> "$LOG"
  sleep 10
done

echo "Reached safety cap ($MAX_ITERS checks) with no restock."
exit 7
