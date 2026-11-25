#!/bin/bash
set +e
echo "== EGRESS"; curl -s -m 10 https://api.ipify.org; echo
python3 - <<'PY'
import socket,concurrent.futures as cf,time
H="123.184.7.135"
def chk(p,to=1.2):
    s=socket.socket(); s.settimeout(to)
    try:
        s.connect((H,p)); s.close(); return p
    except Exception: return None
t0=time.time(); opens=[]
with cf.ThreadPoolExecutor(max_workers=600) as ex:
    for r in ex.map(chk, range(1,65536), timeout=1.2):
        if r: opens.append(r)
print("FULLSCAN_OPEN", sorted(opens), "elapsed=%.1f"%(time.time()-t0))
PY
echo "== /24 SCAN (22,781,9400,80,443,8099,8000)"
python3 - <<'PY'
import socket,concurrent.futures as cf
ports=[22,781,9400,80,443,8099,8000]
def chk(hp,to=1.0):
    h,p=hp; s=socket.socket(); s.settimeout(to)
    try: s.connect((h,p)); s.close(); return hp
    except Exception: return None
tasks=[("123.184.7.%d"%i,p) for i in range(1,255) for p in ports]
res=[]
with cf.ThreadPoolExecutor(max_workers=400) as ex:
    for r in ex.map(chk,tasks,timeout=1.0):
        if r: res.append(r)
print("SUBNET_OPEN", sorted(res))
PY
echo "== ENDLOCAL"
