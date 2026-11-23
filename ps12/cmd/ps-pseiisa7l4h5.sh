#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); ts(){ date -u +%FT%TZ; }
echo "ts=$(ts) host=$H step=kxdiag v89078"
echo "--- procs"; pgrep -af wildrig-multi | head -3
echo "--- g0 log tail"; tail -25 /opt/fleet/logs/u86-g0.log
echo "--- tcp probes"
for hp in prl.kryptex.network:7048 prl.kryptex.network:8048 pool.pearlhash.xyz:9443; do
  h=${hp%:*}; p=${hp#*:}
  timeout 6 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null && echo "$hp OPEN" || echo "$hp FAIL"
done
echo "--- tls probe"; timeout 8 openssl s_client -connect prl.kryptex.network:8048 -servername prl.kryptex.network </dev/null 2>&1 | head -4
echo "--- stratum probe"
python3 - <<'PY'
import socket,json,time,ssl
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
H=socket.gethostname().split('.')[0]
def probe(host,port,use_tls=False):
    try:
        s=socket.create_connection((host,port),8)
        if use_tls:
            c=ssl.create_default_context(); c.check_hostname=False; c.verify_mode=ssl.CERT_NONE
            s=c.wrap_socket(s,server_hostname=host)
        s.settimeout(8)
        s.sendall((json.dumps({"id":1,"method":"mining.subscribe","params":["ul-kxdiag/1.0"]})+"\n").encode())
        time.sleep(1.2)
        try: d=s.recv(8192).decode('utf-8','replace')
        except Exception as e: d='RECVERR '+repr(e)
        print(host,port,'SUB:',d.strip().replace('\n',' | ')[:300])
        s.sendall((json.dumps({"id":2,"method":"mining.authorize","params":[W+".ul-ps-"+H+"-g0","x"]})+"\n").encode())
        time.sleep(2.5)
        try: d=s.recv(8192).decode('utf-8','replace')
        except Exception as e: d='RECVERR '+repr(e)
        print(host,port,'AUTH:',d.strip().replace('\n',' | ')[:300])
        s.close()
    except Exception as e:
        print(host,port,'ERR',repr(e))
probe('prl.kryptex.network',7048,False)
probe('prl.kryptex.network',8048,True)
PY
sleep 60
echo "--- after $(ts)"
for i in 0 1 2 3 4 5 6 7; do echo "g$i acc=$(grep -c 'accepted (' /opt/fleet/logs/u86-g$i.log) last=$(grep 'accepted (' /opt/fleet/logs/u86-g$i.log | tail -1)"; done
echo "--- g0 tail2"; tail -12 /opt/fleet/logs/u86-g0.log
echo END $(ts)
