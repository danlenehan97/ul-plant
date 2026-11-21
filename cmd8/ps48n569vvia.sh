#!/bin/bash
L=/opt/fleet/logs; HN=$(hostname)
echo "=== vstat $(date -u) host=$HN krig=$(pgrep -fc 'krig-miner --coin')"
nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader 2>&1 | head -2
grep -c 'share accepted' $L/krig-$HN-g0.log 2>/dev/null; tail -6 $L/krig-$HN-g0.log 2>/dev/null
echo "--- hb"; bash /opt/fleet/ps8_hb.sh; echo "hb rc=$?"; ls -la /opt/fleet/hb.txt 2>/dev/null
echo "--- cron"; crontab -l 2>/dev/null | tail -4
