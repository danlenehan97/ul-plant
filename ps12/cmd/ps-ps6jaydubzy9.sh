#!/bin/bash
# ul86102 diag23: read-only — why CUDA=stub(802)/OpenCL-empty on ps6; capture the real wrapper.
set -u
L=/opt/fleet; H=$(hostname -s)
echo "== ts $(date -u +%FT%TZ) host $H uid=$(id -u)"
echo "== smi"; which nvidia-smi 2>&1; nvidia-smi -L 2>&1 | head -12
echo "== dev"; ls -l /dev/nvidia* 2>&1 | head -12
echo "== ver"; cat /proc/driver/nvidia/version 2>&1
echo "== lsmod"; lsmod 2>/dev/null | grep -E '^nvidia' | head -8
echo "== dpkg"; dpkg -l 2>/dev/null | grep -E 'nvidia-(driver|dkms|compute|utils|fabricmanager)' | awk '{print $2" "$3}' | head -12
echo "== ldconfig"; ldconfig -p 2>/dev/null | grep -E 'libcuda\.so|libnvidia-opencl|libnvidia-ml|libOpenCL' | head -12
echo "== stubs"; ls -l /usr/local/cuda*/lib64/stubs/libcuda.so* /usr/local/cuda*/targets/x86_64-linux/lib/stubs/libcuda.so* 2>&1 | head -6
echo "== ldconf"; grep -rn 'cuda' /etc/ld.so.conf /etc/ld.so.conf.d/ 2>/dev/null | head -8
echo "== opencl-icd"; ls -l /etc/OpenCL/vendors/ 2>&1; cat /etc/OpenCL/vendors/*.icd 2>/dev/null | head -4; ls -l /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so* 2>&1 | head -4
echo "== fm"; systemctl is-active nvidia-fabricmanager 2>&1; journalctl -u nvidia-fabricmanager -n 12 --no-pager 2>&1 | tail -12
echo "== cuinit-default"; python3 -c "import ctypes;l=ctypes.CDLL('libcuda.so.1');print('rc',l.cuInit(0))" 2>&1 | tail -2
echo "== cuinit-driver-lib"; LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu python3 -c "import ctypes;l=ctypes.CDLL('/usr/lib/x86_64-linux-gnu/libcuda.so.1');print('path-rc',l.cuInit(0))" 2>&1 | tail -2
echo "== wrapper"; cat $L/ps20_g0.sh 2>&1 | head -25; echo "-- files"; ls -l $L/ps*g*.sh $L/w*.sh 2>/dev/null | head -10
echo "== procs"; pgrep -af 'ps20|ps15|ps_sup|wildrig|krig|ul-prl' 2>/dev/null | head -20
echo "== kg0"; tail -4 $L/logs/k-ps-$H-g0.log 2>/dev/null
echo "== wg0"; tail -4 $L/logs/wg0.log 2>&1 | head -6
echo "== DONE diag23 $(date -u +%FT%TZ)"
