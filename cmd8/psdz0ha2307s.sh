#!/bin/bash
L=/opt/fleet/logs; HN=$(hostname)
echo "=== final $(date -u) host=$HN krig=$(pgrep -fc 'krig-miner --coin')"
nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader 2>&1
echo "--- rates"; grep -h 'TH/s' $L/krig-$HN-g*.log 2>/dev/null | tail -8
echo "--- acc"; for f in $L/krig-$HN-g*.log; do printf "%s " $(grep -c 'share accepted' $f); done; echo
echo "--- units"; systemctl is-active nv-cuda-cache@0 nv-cuda-cache@1 nv-cuda-cache@7 2>&1
echo "--- hb"; bash /opt/fleet/ps8_hb.sh; echo "hb rc=$?"
