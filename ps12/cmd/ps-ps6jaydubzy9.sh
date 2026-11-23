#!/bin/bash
# fix25: replace mismatched fabricmanager-580 with exact 535.183.01, re-test CUDA
echo "=== cmd $(date -u +%FT%TZ) host=$(hostname) uid=$(id -u)"
export DEBIAN_FRONTEND=noninteractive

echo "== dmesg-tail"
dmesg 2>/dev/null | grep -iE 'nvrm|xid|fabric|nvidia' | tail -15

echo "== smi-cuda"
nvidia-smi -q -d CUDA 2>&1 | head -30
echo "== smi-q-fabric"
nvidia-smi -q 2>&1 | grep -iA3 'fabric' | head -20
echo "== fm-state"
dpkg -l | grep -i fabricmanager
/usr/bin/nv-fabricmanager --version 2>&1
systemctl is-active nvidia-fabricmanager 2>&1
journalctl -u nvidia-fabricmanager -n 12 --no-pager 2>&1 | tail -12

echo "== fm-available-versions"
apt-cache policy nvidia-fabricmanager-535 nvidia-fabricmanager-580 2>&1 | head -30

echo "== purge-580"
apt-get purge -y -qq nvidia-fabricmanager-580 >/tmp/fm25.purge 2>&1; echo "purge rc=$?"
tail -3 /tmp/fm25.purge

echo "== install-535-exact"
V=$(apt-cache madison nvidia-fabricmanager-535 2>/dev/null | awk '{print $3}' | grep '^535\.183\.01' | head -1)
echo "candidate=$V"
apt-get install -y --reinstall -qq "nvidia-fabricmanager-535=${V:-535.183.01-0ubuntu0.22.04.1}" >/tmp/fm25.inst 2>&1; echo "apt rc=$?"
tail -5 /tmp/fm25.inst
if [ $? -ne 0 ] || ! dpkg -s nvidia-fabricmanager-535 >/dev/null 2>&1; then
  echo "-- apt path failed, trying nvidia deb"
  curl -fsSL -m 120 -o /tmp/fm535.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/nvidia-fabricmanager-535_535.183.01-1_amd64.deb && dpkg -i /tmp/fm535.deb 2>&1 | tail -5
fi

echo "== fm-version-now"
/usr/bin/nv-fabricmanager --version 2>&1
echo "== fm-start"
systemctl unmask nvidia-fabricmanager 2>/dev/null
systemctl enable --now nvidia-fabricmanager 2>&1 | tail -3
sleep 4
systemctl is-active nvidia-fabricmanager 2>&1
journalctl -u nvidia-fabricmanager -n 15 --no-pager 2>&1 | tail -15

echo "== cuinit4"
python3 - <<'PY'
import ctypes,ctypes.util
try:
    l=ctypes.CDLL("libcuda.so.1")
    rc=l.cuInit(0); print("cuInit rc",rc)
    n=ctypes.c_int(0); rc2=l.cuDeviceGetCount(ctypes.byref(n)); print("devcount rc",rc2,"n",n.value)
except Exception as e: print("ERR",e)
PY
echo "== opencl4"
python3 - <<'PY'
import ctypes
try:
    l=ctypes.CDLL("libnvidia-opencl.so.1")
    n=ctypes.c_uint(0); rc=l.clGetPlatformIDs(0,None,ctypes.byref(n)); print("clGetPlatformIDs rc",rc,"n",n.value)
except Exception as e: print("ERR",e)
PY

echo "== wildrig-20s-test"
timeout 20 /opt/fleet/bin/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d 0 -o stratum+ssl://pool.pearlhash.xyz:9443 -u "prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-ps-$(hostname -s)-g0" -p x -i 8 --no-color 2>&1 | tail -25
echo "== smi-after"
nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw --format=csv,noheader 2>&1 | head -8
echo "== DONE fix25 $(date -u +%FT%TZ)"
