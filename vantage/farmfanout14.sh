#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START14 $(date -u +%FT%TZ)"
log "### ENGINE-ENUM"
for e in python calculator sympy bash shell exec os tool code knowledge_graph km search web github math sql file; do
  r=$(timeout 10 curl -s -m 8 -X POST http://192.168.0.22:18000/execute -H 'Content-Type: application/json' \
    -d "{\"engine\":\"$e\",\"operation\":\"run\",\"arguments\":{\"expression\":\"1+1\",\"code\":\"1+1\"}}" -w "|%{http_code}")
  log "$e -> $(echo "$r" | head -c 220 | tr '\n' ' ')"
done
log "### OP-ENUM-PY"
for op in eval exec run execute evaluate call; do
  r=$(timeout 10 curl -s -m 8 -X POST http://192.168.0.22:18000/execute -H 'Content-Type: application/json' \
    -d "{\"engine\":\"python\",\"operation\":\"$op\",\"arguments\":{\"code\":\"print(40+2)\",\"expression\":\"40+2\"}}" -w "|%{http_code}")
  log "$op -> $(echo "$r" | head -c 260 | tr '\n' ' ')"
done
log "### REASON-TOOL"
timeout 40 curl -s -m 35 -X POST http://192.168.0.22:18000/reason -H 'Content-Type: application/json' \
  -d '{"instruction":"Use the python engine to evaluate 40+2 and report the result only.","mode":"symbol_enhanced_neural"}' -w "\nHTTP=%{http_code}\n" | head -c 700
log "### UPLOAD-TRAV"
for fn in "../../../tmp/ul_t1.txt" "..%2f..%2f..%2ftmp%2ful_t2.txt" "/tmp/ul_t3.txt" "....//....//tmp/ul_t4.txt" "uploads/../ul_t5.txt"; do
  r=$(timeout 12 curl -s -m 10 -X POST http://192.168.0.22:14998/upload -F "file=@/tmp/ulp.txt;filename=$fn" -w "|%{http_code}")
  log "fn=$fn -> $(echo "$r" | head -c 200 | tr '\n' ' ')"
done
log "### DL-READBACK"
ID=$(timeout 10 curl -s -m 8 "http://192.168.0.22:14998/files?pageSize=3&search=ulp" | python3 -c "import json,sys
try:
 d=json.load(sys.stdin); print(d['data']['list'][0]['id'])
except: print('')")
log "id=$ID"
[ -n "$ID" ] && timeout 10 curl -s -m 8 "http://192.168.0.22:14998/files/$ID/download" -w "|%{http_code}\n" | head -c 200
log "### DONE14 $(date -u +%FT%TZ)"
