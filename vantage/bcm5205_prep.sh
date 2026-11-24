#!/bin/bash
echo "=== ID"; hostname
echo "=== MINERARGV"; ps -eo pid,args 2>/dev/null | grep -E 'wildrig|srbminer|peakminer' | grep -v grep | head -3
P=$(pgrep -f wildrig | head -1); echo "pid=$P"; [ -n "$P" ] && { readlink -f /proc/$P/exe; md5sum "$(readlink -f /proc/$P/exe)" 2>/dev/null; }
echo "=== BIN"; timeout 20 find / -maxdepth 5 -name 'wildrig*' -type f 2>/dev/null | head -5
echo "=== WALLETCHECK"; timeout 15 curl -s -m 10 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" | head -c 400; echo
echo "=== DCGM"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  echo "--- $h"; timeout 10 curl -s -m 8 "http://$h:9400/metrics" 2>/dev/null | grep -E '# HELP DCGM_FI_DEV_(GPU_UTIL|FB_TOTAL|NAME|MEMORY_TEMP)' -A0 | head -3
  timeout 10 curl -s -m 8 "http://$h:9400/metrics" 2>/dev/null | grep -E '^DCGM_FI_DEV_(GPU_UTIL|FB_TOTAL)' | awk '{print $1, $2}' | head -4
  timeout 10 curl -s -m 8 "http://$h:9400/metrics" 2>/dev/null | grep -oE 'modelName="[^"]*"' | sort -u | head -3
done
echo "=== CONF"; ls -la /root/conf 2>&1 | head -20; head -c 600 /root/conf/hostlist 2>/dev/null; echo
echo "=== DONE"
