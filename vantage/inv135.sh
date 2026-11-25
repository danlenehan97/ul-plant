#!/bin/bash
set +e
echo "### PS-FULL $(date -u +%FT%TZ)"
ps -eo pid,ppid,etime,pcpu,args --sort=-pcpu | head -40
echo "### SS-17048"; ss -tnp 2>/dev/null | grep -E '17048' | head -20
echo "### ULCARD"; systemctl list-units --no-pager 'ul*' 2>/dev/null | head -20; systemctl status 'ul-card@6' --no-pager 2>&1 | head -15
echo "### KEEP"; for f in /root/ul2/keep.sh /root/ul/keep.sh /root/ul/keep-loop.sh /root/ul/sample.sh /opt/t19/sup.sh /opt/t19/relay.py /usr/local/bin/ul-guard.sh; do echo "--- $f"; [ -f "$f" ] && head -40 "$f"; done
echo "### ARGV"; for i in 0 1 6 7; do echo "-- argv-g$i"; cat /root/ul/argv-g$i.txt 2>/dev/null; done
echo "### ULP2"; ls -l /root/ul2 2>/dev/null | head -20; ls -l /root/ul_plant 2>/dev/null | head
echo "### DOCKER"; (docker ps --format '{{.Names}} {{.Image}} {{.Status}}' 2>/dev/null | head -10) || echo no-docker
echo "### CRYPTO-CANDIDATES"; ls -l /dev/shm /tmp 2>/dev/null | head -20
echo "### POOL"; curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" -o /tmp/pw.json -w 'HTTP=%{http_code}\n'
python3 - <<'PY'
import json,time
d=json.load(open('/tmp/pw.json'))['results']; now=time.time()
for r in d:
    if '123-184-7-135' in r['worker']:
        ls=r.get('last_share') or 0
        print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'3h=%s'%r.get('avg_hashrate_3h'))
PY
echo "### DONE $(date -u +%FT%TZ)"
