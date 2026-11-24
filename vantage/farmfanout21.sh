#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START21 $(date -u +%FT%TZ)"
timeout 25 curl -s -m 20 http://192.168.0.24:18086/app.js -o /tmp/app.js
wc -c /tmp/app.js; wc -l /tmp/app.js
log "### ENDPOINTS"
grep -oE '"/api/[A-Za-z0-9_./{}-]+"' /tmp/app.js | sort | uniq -c | sort -rn | head -40
grep -oE "'/api/[A-Za-z0-9_./{}-]+'" /tmp/app.js | sort | uniq -c | sort -rn | head -20
log "### FETCH-CALLS"
grep -oE "fetch\('[^']+'|fetch\(\"[^\"]+\"|axios\.[a-z]+\([^)]{0,80}" /tmp/app.js | head -30
log "### KEYWORDS"
grep -oE '(upload|submit|submission|zip|tar|code|script|exec|entrypoint|runner|job|task|activate|token|admin)[A-Za-z0-9_]*' /tmp/app.js | sort | uniq -c | sort -rn | head -30
log "### SAMPLE-SNIPPETS"
python3 - <<'PY'
import re
s=open('/tmp/app.js',errors='ignore').read()
for kw in ('/api/benchmark','upload','activate','users'):
    for m in list(re.finditer(re.escape(kw), s))[:2]:
        a=max(0,m.start()-220); print('---',kw); print(s[a:m.start()+260].replace('\n',' ')[:520])
PY
log "### API-PROBES"
for p in "/api/benchmark" "/api/users" "/api/user-activation" "/api/datasets" "/api/score" "/api/results" "/api/tasks" "/api/runs"; do
  printf "GET %s -> " "$p"; timeout 10 curl -s -m 8 -o /tmp/o.$$ -w "%{http_code} " "http://192.168.0.24:18086$p"; head -c 220 /tmp/o.$$ | tr '\n' ' '; echo
done
log "### 18080-API"
for p in "/api/datasets" "/api/dataset" "/api/analyze" "/api/upload" "/api/process" "/api/task" "/api/tasks" "/openapi.json" "/api/openapi.json" "/api/docs"; do
  printf "GET %s -> " "$p"; timeout 8 curl -s -m 6 -o /tmp/o2.$$ -w "%{http_code} " "http://192.168.0.24:18080$p"; head -c 160 /tmp/o2.$$ | tr '\n' ' '; echo
done
log "### 781-POST-METRICS"
timeout 10 curl -s -m 8 -X POST http://192.168.0.24:781/metrics -H 'Content-Type: application/json' -d '{"metric":"x","value":1}' -w " [%{http_code}]\n" | head -c 200
log "### FLEET"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
grep -ac beacon /root/ul_farmfan/beacon2.log 2>/dev/null
log "### DONE21 $(date -u +%FT%TZ)"
