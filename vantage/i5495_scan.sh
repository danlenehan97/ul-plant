#!/bin/bash
set +e
H=123.184.7.135
echo "### SCAN $(date -u +%FT%TZ) egress=$(curl -s -m 8 https://api.ipify.org)"
for p in 22 80 443 2222 2375 2376 3000 5000 6443 8000 8080 8081 8188 8265 8888 9000 9090 9400 10250 11398 18086 20000; do
  timeout 4 bash -c "echo > /dev/tcp/$H/$p" 2>/dev/null && echo "OPEN $p" || echo "closed $p"
done
echo "--- docker2375"; timeout 6 curl -s -m 5 http://$H:2375/version | head -c 200; echo
echo "--- dcgm9400"; timeout 6 curl -s -m 5 http://$H:9400/metrics | head -c 200; echo
echo "--- 6443"; timeout 6 curl -sk -m 5 https://$H:6443/version | head -c 200; echo
echo "--- 18086"; timeout 6 curl -s -m 5 http://$H:18086/ | head -c 200; echo
echo "### SCAN-DONE"
