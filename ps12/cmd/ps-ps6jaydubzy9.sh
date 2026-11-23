#!/bin/bash
K=/root/.ssh/ul87804_ed25519
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i $K root@10.140.197.8"
echo "=== PS6 PKGS"
dpkg -l | grep -Ei 'fabric|opencl|nvidia-driver|nvidia-utils|nvidia-compute' | awk '{print $2,$3}' | head -25
echo "=== PS6 FW"
systemctl is-active nvidia-fabricmanager; ls -l /etc/OpenCL/vendors/ 2>&1
echo "=== PS6 MINER"
P=$(pgrep -f 'krig' | head -1); echo "pid=$P"; readlink -f /proc/$P/exe 2>&1; tr '\0' ' ' < /proc/$P/cmdline 2>&1; echo
ls -l /opt/fleet/bin/ 2>&1 | head -12
ls -l /var/cache/apt/archives/ 2>&1 | grep -i fabric | head -5
echo "=== PS6 GPU"
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | head -8
echo "=== .8 PKGS"
$S 'dpkg -l | grep -Ei "fabric|opencl|nvidia-driver|nvidia-utils|nvidia-compute" | awk "{print \$2,\$3}" | head -25' 2>&1
echo "=== .8 OPENCL"
$S 'ls -l /etc/OpenCL/vendors/ 2>&1; ls -l /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so* 2>&1; ls -l /usr/lib/x86_64-linux-gnu/libOpenCL.so* 2>&1' 2>&1
echo "=== .8 BIN"
$S 'ls -l /opt/fleet/bin/ 2>&1 | head -12' 2>&1
echo "=== DIAG2-DONE $(date -u +%FT%TZ)"
