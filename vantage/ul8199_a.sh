#!/bin/bash
set +e
echo "=== UL8199-A $(date -u +%FT%TZ) host=$(hostname) id=$(id -un)"
echo "=== GPU"; nvidia-smi -L 2>/dev/null | head -12
echo "=== MINERS"; pgrep -fa 'plh|krig|wildrig|srbminer|peakminer|forge|pearl' 2>/dev/null | head -30
echo "=== PSARGS"; ps -eo args= 2>/dev/null | grep -Ei 'plh|krig|wildrig|srb|peakminer|forge' | grep -v grep | cut -c1-300 | head -20
echo "=== UNITS"; systemctl list-units --all --no-pager 2>/dev/null | grep -Ei 'plh|nvidia|peer|ul-' | head -20
echo "=== PLHFILES"; ls -la /opt/plh /usr/local/bin/.plhg /usr/local/bin/.plhg* 2>/dev/null | head -30
echo "=== PLHSH"; for f in /opt/plh/*.sh /usr/local/bin/.plhg*; do [ -f "$f" ] && { echo "--- $f"; timeout 5 cat "$f" 2>/dev/null | head -40; }; done
echo "=== SSHKEYS"; ls -la /root/.ssh/ 2>/dev/null | head -20; for k in /root/.ssh/id_* /root/.ssh/*.pem /root/.ssh/*key*; do [ -f "$k" ] && echo "KEYFILE $k $(md5sum "$k" | cut -c1-12)"; done
echo "=== HOSTS"; cat /etc/hosts 2>/dev/null | head -30; echo "-- arp"; ip neigh 2>/dev/null | head -30
echo "=== TOOLS"; for t in mount.nfs showmount nmap nc curl python3 docker; do command -v $t >/dev/null && echo "have $t" || echo "no $t"; done
echo "=== IFCONF"; ip -br a 2>/dev/null | head -20; ip route 2>/dev/null | head -20
echo "=== NFS-TRY"
mkdir -p /mnt/ulrun /mnt/ulapps
for spec in "172.16.10.11:/ssd/run /mnt/ulrun" "10.31.17.2:/ssd/apps /mnt/ulapps"; do
  set -- $spec; SRV=$1; MP=$2
  echo "--- mount $SRV -> $MP"
  timeout 12 mount -t nfs -o nolock,soft,timeo=8,retrans=1,vers=3 "$SRV" "$MP" 2>&1 | head -3
  M=$(mount | grep -c " $MP ")
  echo "mounted=$M"
  if [ "$M" -gt 0 ]; then
    echo "rootdir:"; ls -ln "$MP" 2>&1 | head -15
    TS=$(date +%s)
    echo "marker-$TS" > "$MP/.ul_marker_$TS" 2>&1; echo "write_rc=$?"
    cat "$MP/.ul_marker_$TS" 2>&1
    ls -ln "$MP/.ul_marker_$TS" 2>&1
    stat -c '%U %G %u %g %a' "$MP/.ul_marker_$TS" 2>&1
    # negative control: read-only check on a path we do not own (if exists)
  else
    echo "mount failed: $(timeout 6 rpcinfo -p ${SRV%%:*} 2>&1 | head -5)"
  fi
done
echo "=== SCAN24"
python3 - <<'PY'
import socket, concurrent.futures
ports=[22,80,443,2049,2375,2376,3306,5432,6379,6443,781,8080,8099,9100,9400,9835,10250,10255,14998,18080,18086,19999,18096,18099,8000,8001,8265,8888,11434,18048,18443,19380,19381]
hosts=[f"192.168.0.{i}" for i in range(1,255)]
def one(a):
    h,p=a
    s=socket.socket(); s.settimeout(2.5)
    try:
        if s.connect_ex((h,p))==0: return (h,p)
    except Exception: pass
    finally: s.close()
    return None
tasks=[(h,p) for h in hosts for p in ports]
res=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=120) as ex:
    for r in ex.map(one,tasks):
        if r: res.append(r); print("OPEN",r[0],r[1],flush=True)
print("SCAN-DONE",len(res))
PY
echo "=== DCGM"
python3 - <<'PY'
import urllib.request,json,re
for ip in ["192.168.0.20","192.168.0.21","192.168.0.22","192.168.0.23","192.168.0.24","192.168.0.28","192.168.0.29","192.168.0.30","192.168.0.31"]:
    for p in (9400,9835):
        try:
            r=urllib.request.urlopen(f"http://{ip}:{p}/metrics",timeout=4).read().decode('utf-8','replace')
            names=sorted(set(re.findall(r'DCGM_FI_DEV_NAME\{[^}]*\} "[^"]+"',r)))
            h=[l for l in r.splitlines() if 'Hostname=' in l][:2]
            print(ip,p,"len",len(r),"gpu_names",len(names),names[:3],h[:1])
        except Exception as e:
            pass
PY
echo "=== DOCKER-PROBE"
python3 - <<'PY'
import urllib.request,json
for ip in [f"192.168.0.{i}" for i in range(1,255)]:
    for p in (2375,2376):
        try:
            sch='https' if p==2376 else 'http'
            ctx=None
            import ssl
            if sch=='https':
                ctx=ssl._create_unverified_context()
            r=urllib.request.urlopen(f"{sch}://{ip}:{p}/version",timeout=2.5,context=ctx).read().decode('utf-8','replace')
            print("DOCKER-OPEN",ip,p,r[:160].replace("\n"," "))
        except Exception:
            pass
PY
echo "=== DONE-A"
