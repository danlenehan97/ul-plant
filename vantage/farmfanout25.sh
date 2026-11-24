#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
B=http://192.168.0.24:18086
ID=HIJ-20261125-005939abe2b7
log "### START25 $(date -u +%FT%TZ)"
n=0
for c in \
 '{"content":"aGVsbG8="}' \
 '{"data":"aGVsbG8="}' \
 '{"content_b64":"aGVsbG8="}' \
 '{"filename":"ul.txt","content":"aGVsbG8="}' \
 '{"filename":"ul.txt","data":"aGVsbG8="}' \
 '{"base64":"aGVsbG8="}' \
 '{"content":"hello"}' \
 '{"filename":"ul.txt","file":"aGVsbG8="}' \
 '{"sha256":"8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4","content":"aGVsbG8="}' ; do
  n=$((n+1)); printf '%s' "$c" > /tmp/j$n.txt
  printf "T%s %s -> " $n "$(echo "$c" | head -c 50)"; timeout 12 curl -s -m 10 -X POST "$B/api/submissions/$ID/files/H" -F "file=@/tmp/j$n.txt;filename=ul.txt" -w " [%{http_code}]\n" | head -c 240; echo
done
log "### STATE"
timeout 12 curl -s -m 10 "$B/api/submissions" | python3 -c "
import json,sys
for s in json.load(sys.stdin):
  if s.get('nickname')=='ul-t2-123-184-7-135':
    print('H=',json.dumps(s.get('files',{}).get('H'))[:300]); print('status=',s.get('status'))
" 2>&1 | head -5
log "### DONE25 $(date -u +%FT%TZ)"
