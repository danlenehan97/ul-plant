#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### 135-80/443"
for u in http://123.184.7.135/ https://123.184.7.135/ http://123.184.7.135:80/api/version; do
  echo "-- $u"; timeout 10 curl -sk -m 8 -o /tmp/o -D /tmp/h -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 200 /tmp/o; grep -i "^server:\|^location:" /tmp/h; echo
done
echo "### 152"
for u in http://123.184.7.152/ https://123.184.7.152/ ; do
  echo "-- $u"; timeout 10 curl -sk -m 8 -o /tmp/o -D /tmp/h -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 260 /tmp/o; grep -i "^server:\|^location:" /tmp/h; echo
done
echo "### RAGFLOW-AUTH-ROUTES"
B=http://123.184.7.135:18080
for p in /api/v1/user/login /api/v1/auth/login /api/v1/login /api/v1/user/signin /api/v1/users/login /api/v1/user/register /api/v1/auth/register /api/v1/user/signup /api/v1/system/new_token; do
  for m in POST GET; do
    R=$(timeout 8 curl -s -m 6 -X $m -o /tmp/o -w "%{http_code}" "$B$p" -H 'Content-Type: application/json' -d '{"email":"a@b.c","password":"x"}')
    echo "$m $p => $R :: $(head -c 120 /tmp/o|tr '\n' ' ')"
  done
done
echo "### BUNDLE-GREP"
grep -aoE "v0\.[0-9]+\.[0-9]+|ragflow[^\"']{0,20}" /tmp/idx.js 2>/dev/null | sort -u | head -10
grep -aoE "user/(login|register|info)|auth/(login|register)|/api/v1/[a-z_/]+" /tmp/idx.js 2>/dev/null | sort -u | head -40
echo "### END $(date -u +%FT%TZ)"
