#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### ID3 $(hostname) $(date -u +%FT%TZ)"

log "### G1-GREP-172"
grep -rIl --include='*.sh' --include='*.conf' --include='*.cfg' --include='*.json' --include='*.yaml' --include='*.yml' --include='*.ini' --include='*.py' -E '172\.16\.1[01]\.' /root /etc /opt /ssd /cm 2>/dev/null | grep -v ul_farmfan | head -30
echo "--- matches"
grep -rInE --include='*.sh' --include='*.conf' --include='*.cfg' --include='*.ini' '172\.16\.1[01]\.' /root/conf /etc /opt 2>/dev/null | grep -v ul_farmfan | head -40

log "### G2-GREP-VLAN"
grep -rInE --include='*.sh' --include='*.conf' --include='*.cfg' --include='*.ini' -i 'vlan' /root/conf /etc/sysconfig /opt/avalokita /opt/bcm-agent 2>/dev/null | head -30

log "### G3-TRACE"
which traceroute mtr tracepath 2>&1
timeout 25 traceroute -n -w 1 -m 6 -q 1 172.16.10.1 2>&1 | head -12
timeout 25 traceroute -n -w 1 -m 6 -q 1 172.16.11.13 2>&1 | head -12
timeout 10 ping -c 2 -W 1 172.16.10.1 2>&1 | tail -3
timeout 10 ping -c 2 -W 1 172.16.11.13 2>&1 | tail -3
log "### G4-ROUTEGET"
ip route get 172.16.10.1 2>&1; ip route get 172.16.11.13 2>&1; ip route get 172.16.11.13 from 11.9.141.130 2>&1

log "### V1-VLANLADDER-BOND0"
IDS="2 10 11 12 20 50 100 101 110 120 200 300 1000 2000 4000"
which arping >/dev/null 2>&1 && HAVE_ARPING=1 || HAVE_ARPING=0
log "HAVE_ARPING=$HAVE_ARPING"
for ID in $IDS; do
  ip link add link bond0 name ulv$ID type vlan id $ID 2>&1 || { log "vlan-add-fail $ID"; continue; }
  ip link set ulv$ID up 2>&1
  ip addr add 172.16.10.250/23 dev ulv$ID 2>&1
  sleep 1
  R=""
  if [ "$HAVE_ARPING" = 1 ]; then R=$(timeout 4 arping -c 2 -w 2 -I ulv$ID 172.16.10.1 2>&1 | tr '\n' '|' | head -c 200); fi
  T=$(python3 - <<'PY'
import socket
out=[]
for dst in ["172.16.10.1","172.16.11.1","172.16.10.71","172.16.11.13"]:
  s=socket.socket(); s.settimeout(1.0)
  try:
    s.bind(("172.16.10.250",0)); r=s.connect_ex((dst,22))
  except Exception as e: r=-1
  s.close()
  if r==0: out.append("OPEN:"+dst)
print(",".join(out) or "-")
PY
)
  log "VLAN bond0 id=$ID arp=$R tcp=$T"
  ip addr del 172.16.10.250/23 dev ulv$ID 2>/dev/null
  ip link del ulv$ID 2>/dev/null
done

log "### V2-VLANLADDER-ETH2"
for ID in $IDS; do
  ip link add link eth2 name ulw$ID type vlan id $ID 2>&1 || continue
  ip link set ulw$ID up 2>&1
  ip addr add 172.16.10.251/23 dev ulw$ID 2>&1
  sleep 1
  T=$(python3 - <<'PY'
import socket
out=[]
for dst in ["172.16.10.1","172.16.11.1","172.16.10.71","172.16.11.13"]:
  s=socket.socket(); s.settimeout(1.0)
  try:
    s.bind(("172.16.10.251",0)); r=s.connect_ex((dst,22))
  except Exception: r=-1
  s.close()
  if r==0: out.append("OPEN:"+dst)
print(",".join(out) or "-")
PY
)
  log "VLAN eth2 id=$ID tcp=$T"
  ip addr del 172.16.10.251/23 dev ulw$ID 2>/dev/null
  ip link del ulw$ID 2>/dev/null
done

log "### V3-FARM-PORTS-AFTER"
python3 - <<'PY'
import socket,concurrent.futures
tgts=["172.16.10.1","172.16.10.71","172.16.11.13","172.16.11.1"]
def one(a):
    d,p=a
    s=socket.socket(); s.settimeout(1.2)
    try: r=s.connect_ex((d,p))
    except Exception: r=-1
    s.close(); return (d,p,r)
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as ex:
    for d,p,r in ex.map(one,[(t,p) for t in tgts for p in (22,11398,9400,443,6818)]):
        print("AFTER",d,p,r)
PY
log "### DONE3"
