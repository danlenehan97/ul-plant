#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
B=http://123.184.7.135:18080/api/v1
for p in /system/version /system/status /user/info /user/tenant_info /datasets; do
  echo "-- GET $p"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code}\n" "$B$p"; head -c 260 /tmp/o; echo
done
echo "### REGISTER"
TS=$(date +%s)
for body in "{\"nickname\":\"ul5512\",\"email\":\"ul5512_$TS@ul.local\",\"password\":\"Ul5512!pass\"}" "{\"email\":\"ul5512_$TS@ul.local\",\"password\":\"Ul5512!pass\"}"; do
  echo "-- $body"; timeout 12 curl -s -m 10 -X POST "$B/user/register" -H 'Content-Type: application/json' -d "$body" -w "|%{http_code}\n" | head -c 400; echo
done
echo "### LOGIN"
timeout 12 curl -s -m 10 -X POST "$B/user/login" -H 'Content-Type: application/json' -d "{\"email\":\"ul5512_$TS@ul.local\",\"password\":\"Ul5512!pass\"}" -w "|%{http_code}\n" | head -c 500
echo
echo "### DEFAULT-ADMIN"
for c in '{"email":"admin@ragflow.io","password":"admin"}' '{"email":"admin@ragflow.io","password":"ragflow"}' '{"email":"admin@example.com","password":"admin"}'; do
  echo "-- $c"; timeout 10 curl -s -m 8 -X POST "$B/user/login" -H 'Content-Type: application/json' -d "$c" -w "|%{http_code}\n" | head -c 300; echo
done
echo "### END $(date -u +%FT%TZ)"
