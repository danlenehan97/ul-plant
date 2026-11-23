#!/bin/bash
# ul86067 diag22: CUDA cuInit=802 on A100 SXM/NVSwitch — check fabricmanager + dmesg, try fix.
set -u
L=/opt/fleet; H=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
export DEBIAN_FRONTEND=noninteractive
echo "== ts $(date -u +%FT%TZ) host $H"
echo "== fm"; systemctl status nvidia-fabricmanager --no-pager 2>&1 | head -10
echo "== fmpkg"; dpkg -l 2>/dev/null | grep -i fabric | awk '{print $2" "$3}' | head -5
echo "== fmls"; ls -l /usr/bin/nv-fabricmanager /usr/share/nvidia 2>&1 | head -6
echo "== dmesg"; dmesg 2>/dev/null | grep -iE 'NVRM|Xid|fabric' | tail -25
echo "== nvlink"; nvidia-smi nvlink -s 2>&1 | head -14
echo "== gpuinfo"; head -25 /proc/driver/nvidia/gpus/0000:00:00.0/information /proc/driver/nvidia/gpus/*/information 2>/dev/null | head -30
echo "== apt fm"; apt-get install -y -qq nvidia-fabricmanager-535 >/tmp/fm.log 2>&1; echo "rc=$?"; tail -4 /tmp/fm.log
echo "== start fm"; systemctl enable --now nvidia-fabricmanager >/tmp/fms.log 2>&1; echo "rc=$?"; systemctl is-active nvidia-fabricmanager 2>&1
sleep 6
echo "== cuinit2"; python3 -c "import ctypes;l=ctypes.CDLL('libcuda.so.1');print('cuInit rc',l.cuInit(0))" 2>&1
echo "== wr2"; timeout 20 $L/bin/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://pool.pearlhash.xyz:9443 -u "$W.ul-ps-$H-d3" -p x -i 8 --no-color >/tmp/wr3.log 2>&1; echo "wr rc=$?"; grep -iE 'platform|device|error|fail|accepted|pool' /tmp/wr3.log | head -10
echo "== DONE diag22 $(date -u +%FT%TZ)"
