#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135:18080
timeout 25 curl -s -m 20 "$B/entry/js/index-C2Axc-oG.js" -o /tmp/idx.js -w "code=%{http_code} len=%{size_download}\n"
echo "### ROUTES"
grep -oE '"/v[12]/[a-zA-Z0-9_/{}$.:-]*"' /tmp/idx.js | sort -u | head -40
grep -oE '"(/api)?/[a-z_]+/api/v[12]/[a-zA-Z0-9_/-]*"' /tmp/idx.js | sort -u | head -40
echo "### RAGFLOW-PROBES"
for p in /v1/system/version /v1/system/status /v1/user/info /v1/user/login /v1/dataset /v1/datasets /v2/api/datasets /api/v1/datasets /v1/chat/completion /v1/agent /v1/agents; do
  R=$(timeout 8 curl -s -m 6 -o /tmp/o -w "%{http_code}" "$B$p"); echo "P $p => $R :: $(head -c 200 /tmp/o|tr '\n' ' ')"
done
echo "### LOGIN-TRY"
for c in '{"email":"admin@ragflow.io","password":"admin"}' '{"email":"admin@example.com","password":"admin"}' '{"email":"admin","password":"admin"}'; do
  echo "-- $c"; timeout 10 curl -s -m 8 -X POST "$B/v1/user/login" -H 'Content-Type: application/json' -d "$c" -w "|%{http_code}\n" | head -c 400; echo
done
echo "### END $(date -u +%FT%TZ)"
