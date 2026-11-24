#!/bin/bash
# i202 liveness+inventory probe (read-only) 2026-11-24T10:26:33Z
echo "=== i202 probe $(hostname) $(date -u +%Y-%m-%dT%H:%M:%SZ) marker=2026-11-24T10:26:33Z ==="
id
hostname
cat /etc/machine-id 2>/dev/null
nvidia-smi -L 2>&1 | head -10
nvidia-smi --query-gpu=index,name,memory.total,driver_version,utilization.gpu --format=csv,noheader 2>&1 | head -10
hostname -I 2>/dev/null
curl -s -m 8 https://ifconfig.me 2>/dev/null; echo
ps -eo pid,etime,args 2>/dev/null | grep -E 'krig|srb|wildrig|peakminer' | grep -v grep | head -20
systemctl list-units --no-pager --plain 'nv-cuda-cache*' 2>/dev/null | head -12
crontab -l 2>/dev/null | head -8
ls -la /opt/fleet/bin /opt/fleet/logs 2>/dev/null | head -20
for f in /opt/fleet/logs/*g0*.log; do [ -f "$f" ] && tail -3 "$f"; done 2>/dev/null
echo "=== end i202 probe $(hostname) ==="
