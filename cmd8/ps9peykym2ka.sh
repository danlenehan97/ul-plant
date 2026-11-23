echo "=== DRILL $(date -u) ==="
id; hostname; nvidia-smi -L | head -8
echo "units: $(systemctl list-units 'nv-cuda-cache@*' --no-legend 2>/dev/null | wc -l)"
echo "krig: $(pgrep -fc krig-miner)"
echo "cron: $(crontab -l 2>/dev/null | grep -c nv-krig)"
P=$(pgrep -f krig-miner | head -1); echo "kill9 $P"; kill -9 $P 2>/dev/null
sleep 25
echo "krig_after_25s: $(pgrep -fc krig-miner)"
echo "unit0: $(systemctl is-active nv-cuda-cache@0 2>/dev/null)"
echo "log: $(ls -la /tmp/krig.log 2>/dev/null | awk '{print $5}')"
tail -3 /tmp/krig.log 2>/dev/null
