#!/bin/bash
ts(){ date -u +%FT%TZ; }
echo "=== uldrill $(ts) ==="
P=$(pgrep -f "krig-miner .*ul-ps-pseiisa7l4h5-g3 " | head -1)
echo "PID=$P cmd=$(tr '\0' ' ' </proc/$P/cmdline 2>/dev/null | cut -c1-90)"
kill -9 "$P" && echo "killed $P at $(ts)"
for i in $(seq 1 12); do sleep 10; Q=$(pgrep -f "krig-miner .*ul-ps-pseiisa7l4h5-g3 " | head -1); if [ -n "$Q" ] && [ "$Q" != "$P" ]; then echo "RESPAWN=$Q after $((i*10))s $(ts)"; break; fi; done
sleep 25
tail -3 /opt/fleet/logs/k-ps-pseiisa7l4h5-g3.log
echo "=== END $(ts) ==="
