echo PS6START $(date -u +%H:%M:%S)
ls -l /opt/fleet/krig/ 2>/dev/null | head -6
pgrep -af krig-miner | head -2
for p in $(pgrep -f krig-miner | head -1); do tr '\0' ' ' </proc/$p/cmdline; echo; done
pkill -f ulrelay.py 2>/dev/null
cat >/opt/fleet/bin/ulrelay.py <<'PYEOF'
import socket,threading,sys
lp=int(sys.argv[1]);rh=sys.argv[2];rp=int(sys.argv[3])
s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(("0.0.0.0",lp));s.listen(128)
while 1:
 c,a=s.accept()
 def h(c):
  try:
   u=socket.create_connection((rh,rp),timeout=15)
   def p(x,y):
    try:
     while 1:
      d=x.recv(65536)
      if not d:break
      y.sendall(d)
    except:pass
    try:y.shutdown(socket.SHUT_WR)
    except:pass
   threading.Thread(target=p,args=(c,u),daemon=True).start()
   threading.Thread(target=p,args=(u,c),daemon=True).start()
  except:
   try:c.close()
   except:pass
 h(c)
PYEOF
nohup python3 /opt/fleet/bin/ulrelay.py 17048 prl.kryptex.network 7048 >/opt/fleet/logs/relay7048.log 2>&1 &
nohup python3 /opt/fleet/bin/ulrelay.py 18048 prl.kryptex.network 8048 >/opt/fleet/logs/relay8048.log 2>&1 &
nohup python3 -m http.server 8088 --directory /opt/fleet/krig >/opt/fleet/logs/http8088.log 2>&1 &
sleep 2
ss -lntp 2>/dev/null | grep -E '17048|18048|8088'
timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/17048' && echo RELAY_TCP_OK
timeout 5 bash -c 'exec 3<>/dev/tcp/prl.kryptex.network/7048' && echo KX7048_DIRECT_OK
echo PS6DONE $(date -u +%H:%M:%S)