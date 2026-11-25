#!/bin/bash
set +e
echo "== EGRESS"; curl -s -m 10 https://api.ipify.org; echo
H=123.184.7.135
echo "== TCP PROBE"
for p in 8099 6379 3306 18080 18081 11434 8000 80 443 22; do
  timeout 6 bash -c "echo > /dev/tcp/$H/$p" 2>/dev/null && echo "OPEN $p" || echo "CLOSED $p"
done
echo "== HTTP 8099 ROOT"
curl -s -m 12 -o /tmp/root.html -w 'http=%{http_code} size=%{size_download}\n' "http://$H:8099/"
head -c 500 /tmp/root.html; echo
echo "== HTTP 8099 access.log HEAD"
curl -s -m 12 -o /tmp/acc.log -w 'http=%{http_code} size=%{size_download}\n' "http://$H:8099/access.log"
head -c 300 /tmp/acc.log; echo
echo "== HTTP 80"
curl -s -m 10 -o /dev/null -w 'http80=%{http_code}\n' "http://$H/"
echo "== SSH ul5817"
IMK=/tmp/k1; : > $IMK
if [ -f keys2/ul5817_key ]; then cp keys2/ul5817_key $IMK; chmod 600 $IMK; fi
if [ ! -s $IMK ]; then echo NO_KEY; else
timeout 20 ssh -i $IMK -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=12 -o IdentitiesOnly=yes root@$H 'id; hostname; nvidia-smi -L' 2>&1 | head -10
fi
echo "== ENDLOCAL"
