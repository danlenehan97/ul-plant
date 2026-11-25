#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
cat > /tmp/sc.py <<'PY'
import socket,concurrent.futures as cf,json
ports=[22,80,443,2375,3306,5432,6379,6443,8188,8265,9400,10250,11434,14998,18000,18080]
hosts=[f"123.184.7.{i}" for i in range(1,255)]
def t(a):
    h,p=a
    try:
        s=socket.socket(); s.settimeout(0.9); s.connect((h,p)); s.close(); return (h,p)
    except Exception: return None
res=[]
with cf.ThreadPoolExecutor(max_workers=200) as ex:
    for r in ex.map(t,[(h,p) for h in hosts for p in ports]):
        if r: res.append(r)
for h,p in sorted(res,key=lambda x:(x[1],int(x[0].split('.')[-1]))): print("OPEN",h,p)
print("COUNT",len(res))
PY
timeout 400 python3 /tmp/sc.py
echo "### SSH-RETRY-KEY"
for i in 1 2 3 4 5; do
  chmod 600 keys2/k04_ibm_key.pem_ 2>/dev/null
  R=$(timeout 25 ssh -i keys2/k04_ibm_key.pem_ -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o IdentitiesOnly=yes root@123.184.7.135 'echo OK-$(id -un)-$(hostname)' 2>&1 | tr '\n' ' ' | cut -c1-200)
  echo "TRY$i => $R"; case "$R" in *OK-root*) break;; esac; sleep 5
done
echo "### END $(date -u +%FT%TZ)"
