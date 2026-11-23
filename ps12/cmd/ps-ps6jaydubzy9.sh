#!/bin/bash
# ul86102 fix24: libcuda is a stub (cuInit 802) -> reinstall libnvidia-compute-535, retest CUDA+OpenCL.
set -u
L=/opt/fleet; H=$(hostname -s); export DEBIAN_FRONTEND=noninteractive
echo "== ts $(date -u +%FT%TZ) host $H uid=$(id -u)"
echo "== libcuda"; readlink -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 2>&1; ls -l /usr/lib/x86_64-linux-gnu/libcuda.so* 2>&1
echo "== owner"; dpkg -S /usr/lib/x86_64-linux-gnu/libcuda.so.1 2>&1; dpkg -S /usr/lib/x86_64-linux-gnu/libcuda.so.535.183.01 2>&1
echo "== sizes"; for f in /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so.535.183.01; do [ -e "$f" ] && echo "$f $(stat -c%s "$f")"; done
echo "== stubstr"; [ -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 ] && strings -a /usr/lib/x86_64-linux-gnu/libcuda.so.1 2>/dev/null | grep -ci stub
echo "== compute-pkgs"; dpkg -l 2>/dev/null | grep -E 'libnvidia-compute' | awk '{print $2" "$3}'
echo "== cand"; dpkg -L libnvidia-compute-535 2>/dev/null | grep -E 'libcuda\.so\.535' | head -3
echo "== direct-test"; C=$(dpkg -L libnvidia-compute-535 2>/dev/null | grep -E 'libcuda\.so\.535' | head -1); if [ -n "$C" ]; then python3 -c "import ctypes;l=ctypes.CDLL('$C');print('cand-rc',l.cuInit(0))" 2>&1 | tail -2; fi
echo "== reinstall"; apt-get install -y --reinstall -qq libnvidia-compute-535=535.183.01-0ubuntu0.22.04.1 >/tmp/rc24.log 2>&1; echo "rc=$?"; tail -4 /tmp/rc24.log
ldconfig
echo "== after"; readlink -f /usr/lib/x86_64-linux-gnu/libcuda.so.1; stat -c '%n %s' /usr/lib/x86_64-linux-gnu/libcuda.so.1 2>&1
echo "== cuinit3"; python3 -c "import ctypes;l=ctypes.CDLL('libcuda.so.1');print('rc',l.cuInit(0));n=ctypes.c_int();print('devcount',l.cuDeviceGetCount(ctypes.byref(n)),n.value)" 2>&1 | tail -3
echo "== opencl3"; python3 - <<'PY' 2>&1 | tail -4
import ctypes
o=ctypes.CDLL('libOpenCL.so.1')
n=ctypes.c_uint(0)
r=o.clGetPlatformIDs(0,None,ctypes.byref(n))
print('clGetPlatformIDs rc',r,'platforms',n.value)
PY
echo "== DONE fix24 $(date -u +%FT%TZ)"
