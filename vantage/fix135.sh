#!/bin/bash
# i5495 protocol-order repair + persistence verification on g0023 (8x A800)
set +e
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### IDENT $(date -u +%FT%TZ)"
id; hostname; uname -m
nvidia-smi -L 2>&1 | head -10
ls -l /dev/nvidia* 2>&1 | head -10
nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv,noheader 2>&1 | head -10
echo "### PROCS"
ps -eo pid,etime,args | grep -Ei 'krig|peakminer|wildrig|srbminer|relay.py' | grep -v grep | head -30
echo "### UNITS"
systemctl list-units --no-pager --all 2>/dev/null | grep -iE 'pearl|krig|miner|relay|ul-' | head -20
systemctl is-active ul-pearl-keep 2>&1; systemctl is-enabled ul-pearl-keep 2>&1
echo "### CRON"; crontab -l 2>&1 | head -20
echo "### RC"; ls -l /root/ul 2>&1 | head -20; tail -5 /root/.bashrc 2>/dev/null; ls /etc/cron.d 2>/dev/null
echo "### PROTO-7048 (from this host)"
python3 - <<'PY'
import socket,json,time
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
def test(host,port,tls,order,label):
    print('== %s %s:%d tls=%s %s'%(label,host,port,tls,order))
    try:
        s=socket.create_connection((host,port),timeout=12)
        if tls:
            import ssl; ctx=ssl._create_unverified_context(); s=ctx.wrap_socket(s,server_hostname=host)
        s.settimeout(6)
    except Exception as e:
        print('CONN-FAIL',repr(e)); return
    a=json.dumps({"id":1,"method":"mining.authorize","params":[W+".ul-t2-protofix-g0","x"]})
    b=json.dumps({"id":2,"method":"mining.subscribe","params":["ul/1.0"]})
    seq=[('auth',a),('sub',b)] if order=='auth-first' else [('sub',b),('auth',a)]
    for tag,m in seq:
        s.sendall((m+'\n').encode()); print('SENT',tag,m[:120])
        t0=time.time(); buf=b''
        try:
            while time.time()-t0<4:
                d=s.recv(65536)
                if not d: break
                buf+=d
                if b'\n' in buf: break
        except socket.timeout: pass
        for l in buf.split(b'\n'):
            if l.strip(): print('RECV',tag,l.decode('utf-8','replace')[:220])
    try:
        s.settimeout(8); buf=b''
        t0=time.time()
        while time.time()-t0<8:
            d=s.recv(65536)
            if not d: break
            buf+=d
            if b'\n' in buf: break
        for l in buf.split(b'\n'):
            if l.strip(): print('RECV late',l.decode('utf-8','replace')[:220])
    except socket.timeout: print('late timeout')
    s.close()
test('prl-sg.kryptex.network',7048,False,'auth-first','POS')
test('prl-sg.kryptex.network',7048,False,'sub-first','NEG')
test('prl-sg.kryptex.network',8048,True,'auth-first','POS-TLS')
PY
echo "### RELAY"
ss -lntp 2>/dev/null | grep -E '1704|7048|8048' | head
echo "### POOL-SELF"
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /tmp/pw.json -w 'HTTP=%{http_code} SIZE=%{size_download}\n'
python3 - <<'PY'
import json,time
try:
    d=json.load(open('/tmp/pw.json'))['results']
except Exception as e:
    print('pool parse fail',e); raise SystemExit
now=time.time()
for r in d:
    if '123-184-7-135' in r['worker']:
        ls=r.get('last_share') or 0
        print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'agent=%s'%r.get('agent'))
PY
echo "### REPAIR"
# ensure each device has a live miner; restart via known launch paths
for i in 0 1 2 3 4 5 6 7; do
  if ! pgrep -af "krig|peakminer" | grep -q "g$i\b"; then echo "device $i: no worker process"; fi
done
ls -l /root/ul/*.sh 2>/dev/null | head
for f in /root/ul/cmd-g*.sh /root/ul/ul-pearl*.sh /root/ul/start*.sh; do [ -f "$f" ] && echo "--- $f" && head -20 "$f"; done
echo "### SYSTEMD RECHECK"
systemctl restart ul-pearl-keep 2>&1 | head -5; sleep 20
ps -eo pid,etime,args | grep -Ei 'krig|peakminer' | grep -v grep | wc -l
systemctl is-active ul-pearl-keep
echo "### DONE $(date -u +%FT%TZ)"
