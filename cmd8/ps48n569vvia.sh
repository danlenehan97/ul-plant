#!/bin/bash
B=/opt/fleet; L=$B/logs
echo "=== vdiag $(date -u) host=$(hostname)"
cat /etc/os-release | head -3; ldd --version | head -1
nvidia-smi -L 2>&1 | head -2
echo "krig=$(pgrep -fc 'krig-miner --coin')"
ls -la $B/krig/ 2>/dev/null
$B/krig/krig-miner --version 2>&1 | head -3
echo "--- ldd"; ldd $B/krig/krig-miner 2>&1 | grep -i 'not found\|GLIBC' | head -5
echo "--- err"; for f in $L/krig-*.err; do [ -f "$f" ] && { echo "$f"; tail -4 "$f"; }; done
echo "--- ps8log"; tail -8 $L/ps8.log 2>/dev/null
