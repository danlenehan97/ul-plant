#!/bin/bash
K=/root/.ssh/ul87804_ed25519
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i $K root@10.140.197.8"
echo "=== PRE $(date -u +%FT%TZ)"
$S 'hostname; uptime -p; systemctl is-active nvidia-fabricmanager; nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | head -8' 2>&1
echo "=== JOURNAL unit2"
$S 'journalctl -u nv-cuda-cache@2 --no-pager -n 12 2>&1 | tail -12' 2>&1
echo "=== PKG policy"
$S 'apt-cache policy nvidia-fabricmanager-535 2>&1 | head -4' 2>&1
echo "=== INSTALL"
$S 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq 2>&1 | tail -2; timeout 420 apt-get install -y -o DPkg::Lock::Timeout=300 nvidia-fabricmanager-535 2>&1 | tail -6; systemctl enable --now nvidia-fabricmanager 2>&1 | tail -2; systemctl is-active nvidia-fabricmanager' 2>&1
echo "=== RESTART UNITS"
$S 'for i in 0 1 2 3 4 5 6 7; do systemctl restart nv-cuda-cache@$i; done; sleep 25; nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | head -8; journalctl -u nv-cuda-cache@2 --no-pager -n 8 2>&1 | tail -8' 2>&1
echo "=== FW-DONE $(date -u +%FT%TZ)"
