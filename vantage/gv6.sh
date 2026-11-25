#!/bin/bash
set +e
H=123.184.7.135
log(){ echo "$@"; }
log "### GV6 $(date -u +%FT%TZ)"

log "### L1-8090"
timeout 8 curl -s "http://$H:8090/" | sed -n 1,60p
log "### L2-8099"
timeout 8 curl -s "http://$H:8099/" | sed -n 1,60p
log "### L3-8899"
timeout 8 curl -s "http://$H:8899/" | sed -n 1,60p
log "### L4-9099"
timeout 8 curl -s "http://$H:9099/docs" | head -c 400; echo
timeout 8 curl -s "http://$H:9099/openapi.json" | head -c 1500; echo

log "### A1-81"
timeout 8 curl -s "http://$H:81/" | sed -n 1,40p
log "### A2-443"
timeout 8 curl -sk "https://$H/" | head -40
timeout 8 curl -sk "https://$H/assets/" -o /dev/null -w '%{http_code}\n'
log "### A3-18021-openagent"
for p in / /login /index /api /api/login /prod-api/ /swagger-ui.html /v3/api-docs /actuator /actuator/env /actuator/health; do
  R=$(timeout 6 curl -s -o /tmp/o -w '%{http_code} %{size_download}' "http://$H:18021$p"); echo "OA $p -> $R"; head -c 200 /tmp/o; echo
done
log "### A4-18020"
for p in / /login /api/login /actuator/health /swagger-ui.html /v3/api-docs; do
  R=$(timeout 6 curl -s -o /tmp/o2 -w '%{http_code} %{size_download}' "http://$H:18020$p"); echo "P18020 $p -> $R"; head -c 200 /tmp/o2; echo
done
log "### A5-RAGFLOW"
for p in /v1/api/version /api/v1/version /v1/user/info /v1/system/version /v1/system/status /v1/document/list /v1/dataset /v1/kb/list /api/v1/user/info /healthz; do
  R=$(timeout 8 curl -s -o /tmp/r -w '%{http_code} %{size_download}' "http://$H:18080$p"); echo "RAG $p -> $R"; head -c 400 /tmp/r; echo
done
log "### A6-ONLYOFFICE"
timeout 8 curl -s -o /tmp/oo -w 'oo-index %{http_code} %{size_download}\n' "http://$H:18081/index.html"; grep -oE 'version[^,]{0,40}' /tmp/oo | head -5
for p in /healthcheck /web-apps/apps/api/documents/api.js /coauthoring/CommandService.ashx /info/info.json; do
  R=$(timeout 6 curl -s -o /tmp/o3 -w '%{http_code} %{size_download}' "http://$H:18081$p"); echo "OO $p -> $R"; head -c 200 /tmp/o3; echo
done
log "### A7-19380"
for p in / /docs /openapi.json /swagger /api/version /health /actuator/health; do
  R=$(timeout 6 curl -s -o /tmp/o4 -w '%{http_code} %{size_download}' "http://$H:19380$p"); echo "P19380 $p -> $R"; head -c 200 /tmp/o4; echo
done
log "### A8-16002"
timeout 8 curl -sk "https://$H:16002/" | head -20
log "### A9-13308"
timeout 6 curl -s -o /tmp/o5 -w 'p13308 %{http_code} %{size_download}\n' "http://$H:13308/"; head -c 300 /tmp/o5; echo
log "### A10-MINIO-CREDS"
for C in "minioadmin:minioadmin" "admin:minioadmin" "minio:minio123"; do
  R=$(timeout 6 curl -s -u "$C" -o /tmp/m -w '%{http_code}' "http://$H:9101/"); echo "MINIO $C -> $R"; head -c 120 /tmp/m; echo
done
log "### A11-MYSQL"
python3 - <<'PY'
import socket
H="123.184.7.135"
def try_mysql(u,p):
    import struct
    try:
        s=socket.create_connection((H,3306),6); s.settimeout(5)
        greet=s.recv(1024)
        print("GREET",greet[:60])
    except Exception as e:
        print("CONNFAIL",e); return
    s.close()
try_mysql("root","")
PY
log "### DONE6"
