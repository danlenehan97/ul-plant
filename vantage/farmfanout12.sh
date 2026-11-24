#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START12 $(date -u +%FT%TZ)"
log "### API-14998"
timeout 10 curl -s -m 8 http://192.168.0.22:14998/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('title',d.get('info',{}).get('title'))
for p,m in d.get('paths',{}).items():
    for meth,op in m.items():
        print(meth.upper(),p,'|',op.get('summary',''))
        body=op.get('requestBody',{}).get('content',{})
        for ct,sc in body.items():
            sch=sc.get('schema',{})
            print('   body',ct,json.dumps(sch)[:300])
        for prm in op.get('parameters',[]) or []:
            print('   param',prm.get('name'),prm.get('in'),prm.get('required'),json.dumps(prm.get('schema',{}))[:120])
" 2>&1 | head -60
log "### API-18000"
timeout 10 curl -s -m 8 http://192.168.0.22:18000/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('title',d.get('info',{}).get('title'))
for p,m in d.get('paths',{}).items():
    for meth,op in m.items():
        print(meth.upper(),p,'|',op.get('summary',''))
        body=op.get('requestBody',{}).get('content',{})
        for ct,sc in body.items():
            print('   body',ct,json.dumps(sc.get('schema',{}))[:400])
" 2>&1 | head -60
log "### PROBE-14998"
timeout 8 curl -s -m 6 -o /tmp/a -w "root=%{http_code}\n" http://192.168.0.22:14998/; head -c 200 /tmp/a; echo
for p in /files /list /api/files /api/file/list /download /api/download /status; do
  log "-- GET $p"; timeout 6 curl -s -m 5 -o /tmp/b -w "http=%{http_code} " "http://192.168.0.22:14998$p"; head -c 150 /tmp/b; echo
done
log "### PROBE-18000-EXEC"
timeout 10 curl -s -m 8 -X POST http://192.168.0.22:18000/execute -H 'Content-Type: application/json' -d '{"query":"hello","engine":"calculator","input":"1+1"}' | head -c 500; echo
log "### DONE12 $(date -u +%FT%TZ)"
