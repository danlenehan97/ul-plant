#!/bin/bash
H=$(hostname)
echo "== before $(date -u)"; pgrep -af krig-miner | cut -c1-120 | head -3
pkill -9 -f krig-miner
sleep 3
echo "== 3s after kill"; pgrep -c -f krig-miner
sleep 40
echo "== 43s after kill"; pgrep -af krig-miner | cut -c1-120 | head -3
systemctl is-active nv-cuda-cache@0 2>&1
echo "== units"; systemctl list-units 'nv-cuda-cache@*' --plain --no-legend 2>&1 | head -4
