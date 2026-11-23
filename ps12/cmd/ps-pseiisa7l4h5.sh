#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "ts=$(date -u +%FT%TZ) host=$(hostname -s) up=$(cut -d' ' -f1 /proc/uptime)"
echo "guard=$(systemctl is-active ul86-guard 2>&1) fw=$(systemctl is-active nvidia-fabricmanager 2>&1) cleap=$(command -v clinfo || echo no-clinfo)"
nvidia-smi --query-gpu=index,name,driver_version,memory.used,utilization.gpu --format=csv,noheader 2>&1 | sed 's/^/GPU /'
echo "wr=$(pgrep -c -x wildrig-multi 2>/dev/null) krig=$(pgrep -c -x krig-miner 2>/dev/null) peak=$(pgrep -c -x peakminer 2>/dev/null)"
echo "--- units"; systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -10
echo "--- argv"; p=$(pgrep -x wildrig-multi | head -1); [ -n "$p" ] && tr '\0' ' ' < /proc/$p/cmdline && echo
for i in 0 1 2 3 4 5 6 7; do f=/opt/fleet/logs/u86-g$i.log; echo "g$i acc=$(grep -c 'accepted (' $f 2>/dev/null) last=$(grep 'accepted (' $f 2>/dev/null | tail -1 | tr -d '\r') hr=$(grep -oE '[0-9.]+ [KMGTH]+/s' $f 2>/dev/null | tail -1)"; done
echo "--- tails"; for i in 0 3 7; do echo "g$i: $(tail -2 /opt/fleet/logs/u86-g$i.log 2>/dev/null | tr '\n' '|')"; done
echo "--- probes"
for hp in prl.kryptex.network:8048 prl.kryptex.network:7048 pool.pearlhash.xyz:9000 pool.pearlhash.xyz:9443 pearl.luckypool.io:3360; do h=${hp%:*}; pp=${hp#*:}; timeout 5 bash -c "exec 3<>/dev/tcp/$h/$pp" 2>/dev/null && echo "$hp open" || echo "$hp closed"; done
echo "--- kxapi"; curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | head -c 1200; echo
echo "--- pseiisa-in-kx"; curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr ',' '\n' | grep -c 'pseiisa' 
echo "--- phapi"; curl -s -m 25 "https://pool.pearlhash.xyz/api/stats_address?address=$W" | head -c 600; echo
echo "--- krig-on-ps6-lan"; timeout 5 bash -c 'exec 3<>/dev/tcp/10.140.197.2/22' 2>/dev/null && echo ps6:22 open || echo ps6:22 closed
echo "--- clinfo"; (timeout 20 clinfo -l 2>&1 | head -12) || true
