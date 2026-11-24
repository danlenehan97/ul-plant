#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
B=http://192.168.0.24:18086
ID=HIJ-20261125-005939abe2b7
log "### START24 $(date -u +%FT%TZ)"
printf 'hello-ul' > /tmp/t1.txt
printf 'aGVsbG8tdWw=' > /tmp/t2.b64
log "### JSON-LADDER"
for body in \
 '{"filename":"ul.txt","content":"aGVsbG8tdWw="}' \
 '{"filename":"ul.txt","data":"aGVsbG8tdWw="}' \
 '{"filename":"ul.txt","content_b64":"aGVsbG8tdWw="}' \
 '{"filename":"ul.txt","base64":"aGVsbG8tdWw="}' \
 '{"name":"ul.txt","content":"aGVsbG8tdWw="}' \
 '{"filename":"ul.txt","content":"hello-ul"}' \
 '{"filename":"ul.txt","text":"hello-ul"}' ; do
  printf "J %s -> " "$(echo "$body" | head -c 46)"; timeout 12 curl -s -m 10 -X POST "$B/api/submissions/$ID/files/H" -H 'Content-Type: application/json' -d "$body" -w " [%{http_code}]\n" | head -c 220; echo
done
log "### TEXT-MULTIPART"
for f in /tmp/t1.txt /tmp/t2.b64; do
  for fn in ul.txt "../../../../etc/cron.d/ulb"; do
    printf "M %s fn=%s -> " "$f" "$fn"; timeout 12 curl -s -m 10 -X POST "$B/api/submissions/$ID/files/H" -F "file=@$f;filename=$fn" -w " [%{http_code}]\n" | head -c 220; echo
  done
done
log "### STATE"
timeout 12 curl -s -m 10 "$B/api/submissions" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for s in d:
  if s.get('nickname')=='ul-t2-123-184-7-135':
    print('H=',json.dumps(s.get('files',{}).get('H')))
    print('status=',s.get('status'))
" 2>&1 | head -6
log "### JS-FILES-ROUTE"
timeout 25 curl -s -m 20 $B/app.js -o /tmp/app.js
grep -oE "api/submissions/[^'\"]*files[^'\"]*" /tmp/app.js | sort -u | head -10
grep -oE "files/[A-Z]|/files['\"]|content|base64|sha256" /tmp/app.js | sort | uniq -c | sort -rn | head -12
log "### FLEET"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
log "### DONE24 $(date -u +%FT%TZ)"
