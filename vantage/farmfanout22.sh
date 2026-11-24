#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START22 $(date -u +%FT%TZ)"
timeout 25 curl -s -m 20 http://192.168.0.24:18086/app.js -o /tmp/app.js
timeout 20 curl -s -m 15 http://192.168.0.24:18086/ -o /tmp/p.html
log "### ACCEPT"
grep -oE 'accept="[^"]*"' /tmp/p.html | sort -u | head -5
grep -oE 'type="file"[^>]*' /tmp/p.html | head -5
log "### SUBMIT-SNIPPET"
python3 - <<'PY'
import re
s=open('/tmp/app.js',encoding='utf-8',errors='replace').read()
for kw in ('/api/submissions','FormData','uploading','file'):
    idx=[m.start() for m in re.finditer(re.escape(kw),s)][:3]
    for i in idx:
        print('---',kw)
        print(s[max(0,i-300):i+420].replace('\n',' ')[:720])
PY
log "### SCHEMA-PROBE"
for body in '{}' '{"user":"x"}' '{"contexts":[]}' '{"name":"x","files":[]}'; do
  printf "POST %s -> " "$body"; timeout 12 curl -s -m 10 -X POST http://192.168.0.24:18086/api/submissions -H 'Content-Type: application/json' -d "$body" -w " [%{http_code}]\n" | head -c 260; echo
done
log "### MP-PROBE"
printf 'a,b\n1,2\n' > /tmp/sub.csv
timeout 15 curl -s -m 12 -X POST http://192.168.0.24:18086/api/submissions -F "file=@/tmp/sub.csv;filename=sub.csv" -F "user=ul" -w " [%{http_code}]\n" | head -c 300
log "### BENCH-FULL"
timeout 15 curl -s -m 12 http://192.168.0.24:18086/api/benchmark | head -c 1200
log "### SUBS-LIST"
timeout 15 curl -s -m 12 http://192.168.0.24:18086/api/submissions | head -c 900
log "### 18080-DATASETS"
timeout 15 curl -s -m 12 http://192.168.0.24:18080/api/datasets | head -c 700
log "### FLEET"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
log "### DONE22 $(date -u +%FT%TZ)"
