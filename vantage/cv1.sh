#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### CV1 $(date -u +%FT%TZ)"
S=$(timeout 8 curl -s "http://$H:8099/seq" | tr -dc 0-9)
N=$(date +%s)
log "seq_before=$S new=$N"
log "--- put cmd"
timeout 15 curl -s -o /tmp/pc -w '%{http_code}\n' -X POST --data-binary @vantage/ul5817_cmd1.sh "http://$H:8099/put/cmd.sh"; cat /tmp/pc; echo
log "--- put seq"
timeout 10 curl -s -o /tmp/ps -w '%{http_code}\n' -X POST --data-binary "$N" "http://$H:8099/put/seq"; cat /tmp/ps; echo
sleep 35
log "--- seq after"; timeout 8 curl -s "http://$H:8099/seq"; echo; timeout 8 curl -s "http://$H:8099/.seq"; echo
log "--- output"
timeout 10 curl -s "http://$H:8099/ul5817_a.txt" | head -120
log "### DONE-CV1"
