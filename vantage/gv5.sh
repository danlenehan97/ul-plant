#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### GV5 $(date -u +%FT%TZ) target=$H"

log "### P0-SCAN"
python3 - <<PY
import socket,concurrent.futures
H="$H"
ports=[22,81,443,3306,5555,6379,8080,8090,8099,8899,9099,9101,9102,11434,13308,16002,16003,17048,18020,18021,18080,18081,18089,18443,19100,19101,19380,19381,19382]
def one(p):
    s=socket.socket(); s.settimeout(4)
    r=s.connect_ex((H,p)); s.close(); return (p,r)
with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
    for p,r in sorted(ex.map(one,ports)):
        print(("OPEN " if r==0 else "closed ")+str(p)+" r="+str(r),flush=True)
PY

log "### P1-HTTP"
for P in 81 443 8080 8090 8099 8899 9099 18020 18021 18080 18081 18089 18443 19100 19101 19380 19381 19382 13308 16002 16003 9101 9102; do
  for SCHEME in http https; do
    R=$(timeout 6 curl -sk -o /tmp/b.$P.$SCHEME -w '%{http_code} %{size_download} %{content_type}' "${SCHEME}://$H:$P/" 2>/dev/null)
    case "$R" in 000*) ;; *) echo "HIT $P $SCHEME -> $R"; head -c 300 /tmp/b.$P.$SCHEME 2>/dev/null | tr -d '\0' | head -5; echo;; esac
  done
done

log "### P2-REDIS"
python3 - <<PY
import socket
H="$H"
def cmd(sock,c):
    sock.sendall((c+"\r\n").encode()); import time; time.sleep(0.4)
    try: return sock.recv(65535).decode('utf-8','replace')
    except Exception as e: return "ERR:"+str(e)
for p in (6379,):
    try:
        s=socket.create_connection((H,p),5); s.settimeout(4)
    except Exception as e:
        print("REDIS connect fail",e); continue
    for c in ["PING","INFO server","CONFIG GET dir","CONFIG GET dbfilename","ACL WHOAMI","DBSIZE","INFO keyspace"]:
        print("--- redis",c); print(cmd(s,c)[:900],flush=True)
    s.close()
PY

log "### P3-MINIO"
timeout 6 curl -s -o /dev/null -w 'minio-live %{http_code}\n' "http://$H:9101/minio/health/live"
timeout 6 curl -s "http://$H:9101/" | head -c 300; echo

log "### P4-JUPYTER"
for P in 18089 18081 8080 8090 8099 8899 9099 443; do
  for PATHX in "/api/kernels" "/api/status" "/lab" "/tree" "/api/contents/" "/jupyter/api/kernels"; do
    R=$(timeout 6 curl -sk -o /tmp/j.out -w '%{http_code}' "https://$H:$P$PATHX" 2>/dev/null)
    R2=$(timeout 6 curl -s -o /tmp/j2.out -w '%{http_code}' "http://$H:$P$PATHX" 2>/dev/null)
    case "$R$R2" in *200*|*302*) echo "JPATH $P $PATHX https=$R http=$R2"; head -c 200 /tmp/j.out; head -c 200 /tmp/j2.out; echo;; esac
  done
done

log "### P5-SSH"
timeout 12 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 root@$H 'id -u' 2>&1 | head -3
timeout 12 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -i keys2/k04_ibm_key.pem_ -o IdentitiesOnly=yes root@$H 'id -u' 2>&1 | head -3
log "### DONE5"
