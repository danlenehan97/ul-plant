#!/bin/bash
# ul86067 diag21: CUDA/OpenCL init failure — check nvidia_uvm and retest engines.
set -u
L=/opt/fleet; H=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "== ts $(date -u +%FT%TZ) host $H"
echo "== ver"; cat /proc/driver/nvidia/version 2>&1
echo "== lsmod"; lsmod 2>/dev/null | grep -E 'nvidia|uvm' | head -8
echo "== dev"; ls -l /dev/nvidia* 2>&1 | head -14
echo "== modprobe uvm"; modprobe nvidia_uvm 2>&1; echo "rc=$?"
echo "== nvidia-modprobe"; nvidia-modprobe -u -c 0 2>&1; echo "rc=$?"
echo "== dev2"; ls -l /dev/nvidia-uvm* 2>&1
echo "== cuinit"; python3 -c "import ctypes;l=ctypes.CDLL('libcuda.so.1');print('cuInit rc',l.cuInit(0))" 2>&1
echo "== wr"; timeout 22 $L/bin/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://pool.pearlhash.xyz:9443 -u "$W.ul-ps-$H-d2" -p x -i 8 --no-color >/tmp/wr2.log 2>&1; echo "wr rc=$?"; grep -iE 'platform|device|error|fail|accepted|difficulty|pool' /tmp/wr2.log | head -12
echo "== krig"; timeout 12 $L/krig/krig-miner --list-devices 2>&1 | head -12
echo "== nvidia-q"; nvidia-smi --query-gpu=index,compute_mode,mig.mode.current,pstate --format=csv,noheader 2>&1 | head -8
echo "== DONE diag21 $(date -u +%FT%TZ)"
