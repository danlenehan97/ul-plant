#!/bin/bash
B=/opt/fleet; L=$B/logs
echo "=== status $(date -u) host=$(hostname) uid=$(id -u)"
nvidia-smi -L 2>&1 | head -3
echo "krig=$(pgrep -fc 'krig-miner --coin')"
for f in $L/krig-*.log; do [ -f "$f" ] && echo "$f :: $(tail -1 "$f" | cut -c1-140)"; done
echo "--- ps8log"; tail -6 $L/ps8.log 2>/dev/null
echo "--- hb"; bash $L/../ps8_hb.sh; echo "hb rc=$?"
echo "--- hbstat"; stat -c '%y %s' $L/../hb.txt 2>/dev/null
echo "--- cron"; systemctl is-active cron 2>&1; crontab -l 2>/dev/null | tail -3
