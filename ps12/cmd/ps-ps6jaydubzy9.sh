#!/bin/bash
# ul86099 diagnostic on ps6jaydubzy9 — why do krig/wildrig see zero devices while nvidia-smi sees 8?
exec 2>&1
echo "== DIAG $(date -u +%FT%TZ) uid=$(id -u) host=$(hostname) bootid=$(cat /proc/sys/kernel/random/boot_id)"
echo "== uptime"; uptime
echo "== nvidia nodes"; ls -l /dev/nvidia* 2>&1 | head -15
echo "== uvm nodes"; ls -l /dev/nvidia-uvm* 2>&1
echo "== lsmod"; lsmod | grep -E '^(nvidia|nvidia_uvm|nvidia_drm|nvidia_modeset)'
echo "== procver"; cat /proc/driver/nvidia/version 2>&1
echo "== lspci"; lspci -nn 2>/dev/null | grep -i -E 'nvidia|3d controller' | head -12
echo "== smiq"; nvidia-smi -q 2>&1 | head -70
echo "== query"; nvidia-smi --query-gpu=index,name,compute_mode,persistence_mode,driver_version,pci.bus_id,serial --format=csv 2>&1
echo "== topo"; nvidia-smi topo -m 2>&1 | head -12
echo "== env"; env | grep -iE 'cuda|nvidia|opencl|ld_' | head -20
echo "== libs"; ls -l /usr/lib/x86_64-linux-gnu/libcuda.so* /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so* /usr/lib/x86_64-linux-gnu/libnvidia-ml.so* 2>&1 | head -20
echo "== opencl"; ls -l /etc/OpenCL/vendors/ 2>&1; cat /etc/OpenCL/vendors/*.icd 2>/dev/null
echo "== dmesg"; dmesg 2>/dev/null | grep -iE 'nvidia|uvm|nvrm' | tail -25
echo "== modprobe uvm"; modprobe nvidia_uvm 2>&1; sleep 2; ls -l /dev/nvidia-uvm* 2>&1
echo "== krig listdev"; timeout 20 /opt/fleet/krig/krig-miner --list-devices 2>&1 | head -25
echo "== runner g0"; cat /opt/fleet/ps15_g0.sh 2>&1
echo "== krig run g0 18s"; timeout 18 env CUDA_VISIBLE_DEVICES=0 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-ps-ps6jaydubzy9-g0 --password x --no-tui --no-telemetry -l info 2>&1 | head -30
echo "== DONE $(date -u +%FT%TZ)"
