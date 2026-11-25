#!/bin/bash
set +e
echo "=== WATCH $(date -u +%FT%TZ)"
echo "--- /opt/nv"; sudo -n ls -la /opt/nv 2>&1 | head -20
echo "--- keep.sh"; sudo -n cat /opt/nv/keep.sh 2>&1 | head -c 6000
echo; echo "--- units state"
for u in nv-cuda-cache.service nv-t19.service nv-t19v.service t19-keep.service t19-keep9.service t19k-keep.service ul-nvpm.service; do echo "$u: $(sudo -n systemctl is-active $u 2>/dev/null)/$(sudo -n systemctl is-enabled $u 2>/dev/null)"; done
echo "--- miner"; pgrep -af pearl-gpu-miner | head -3; tail -3 /home/ubuntu/ul7256/prl-g0.log 2>/dev/null
echo "=== WATCH END"
