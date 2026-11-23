#!/bin/bash
echo "ts=$(date -u +%FT%TZ) host=$(hostname) up=$(cut -d' ' -f1 /proc/uptime)"
echo "guard=$(systemctl is-active ul86-guard 2>&1) units=$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | grep -c running) wr=$(pgrep -c -x wildrig-multi 2>/dev/null)"
for i in 0 1 2 3 4 5 6 7; do
  f=/opt/fleet/logs/u86-g$i.log
  echo "g$i acc=$(grep -c 'accepted (' $f 2>/dev/null) last=$(grep 'accepted (' $f 2>/dev/null | tail -1 | tr -d '\r') hr=$(grep -oE '[0-9.]+ [KMGTH]+/s' $f 2>/dev/null | tail -1)"
done
echo "poolapi=$(curl -s -m 20 'https://pool.pearlhash.xyz/api/stats_address?address=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz' | head -c 2500)"
echo "kxapi=$(curl -s -m 20 'https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz' | head -c 1500)"
