#!/bin/bash
set +e
echo "=== VERIFY $(date -u +%FT%TZ) host=$(hostname)"
echo "--- before"; pgrep -af 'pearl-gpu-miner' | head -3
ps -o pid=,etimes=,cmd= -C pearl-gpu-miner 2>/dev/null | head -3
tail -4 /home/ubuntu/ul7256/prl-g0.log
grep -acE 'accepted' /home/ubuntu/ul7256/prl-g0.log
grep -aoE 'accepted \([0-9]+/[0-9]+\)' /home/ubuntu/ul7256/prl-g0.log | tail -2
echo "--- drill: kill -9 miner, wait 40s"
P=$(pgrep -f 'pearl-gpu-miner' | head -1); echo "killed=$P"; kill -9 $P 2>/dev/null
sleep 40
echo "--- after"; pgrep -af 'pearl-gpu-miner' | head -3
tail -3 /home/ubuntu/ul7256/prl-g0.log
echo "--- unit"; sudo -n systemctl is-active ul-nvpm.service; sudo -n systemctl is-enabled ul-nvpm.service
echo "--- cron"; sudo -n cat /etc/cron.d/ul-nvpm
echo "--- utilization"; nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader
echo "=== VERIFY END"
