#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### .199-18000"
for u in "http://123.184.7.199:18000/" "http://123.184.7.199:18000/health" "http://123.184.7.199:18000/tools" "http://123.184.7.199:18000/openapi.json"; do
  echo "-- $u"; timeout 12 curl -s -m 10 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 600 /tmp/o; echo
done
echo "### .199-ports"
for p in 22 80 443 14998 18080 18000 9400 11434 6379; do
  ( timeout 3 bash -c "echo > /dev/tcp/123.184.7.199/$p" 2>/dev/null && echo "OPEN $p" ) &
done; wait
echo "### .199-exec"
for b in '{"engine":"calculator","operation":"evaluate","arguments":{"expression":"1+1"}}' '{"engine":"relational_db","operation":"query","arguments":{"sql":"select * from pragma_database_list"}}'; do
  echo "-- $b"; timeout 12 curl -s -m 10 -X POST http://123.184.7.199:18000/execute -H 'Content-Type: application/json' -d "$b" -w "|%{http_code}\n" | head -c 400; echo
done
echo "### REDIS-135"
python3 - <<'PY'
import socket
def cmd(s,*a):
    q=b"*%d\r\n"%len(a)+b"".join(b"$%d\r\n%s\r\n"%(len(x),x) for x in [y.encode() if isinstance(y,str) else y for y in a])
    s.sendall(q); import time; time.sleep(0.4)
    try: return s.recv(65535)
    except Exception as e: return b"ERR:"+str(e).encode()
try:
    s=socket.create_connection(("123.184.7.135",6379),6); s.settimeout(4)
    for c in [("PING",),("INFO","server"),("CONFIG","GET","dir"),("CONFIG","GET","dbfilename"),("ACL","WHOAMI"),("CONFIG","GET","requirepass"),("MODULE","LIST")]:
        print("CMD",c,"=>",cmd(s,*c)[:600])
except Exception as e:
    print("REDIS-ERR",e)
PY
echo "### END $(date -u +%FT%TZ)"
