#!/bin/bash
set +e
R=http://123.184.7.135:18080
echo "=== bundle api refs"
curl -s -m 15 "$R/entry/js/index-C2Axc-oG.js" -o /tmp/j1 -w 'j1 %{http_code} %{size_download}\n'
grep -oE '(api/v1|/v1)/[a-zA-Z0-9_/.-]{2,50}' /tmp/j1 | sort | uniq -c | sort -rn | head -30
grep -oE '"[a-z]+/[a-z0-9_/.-]*login[a-z0-9_/.-]*"' /tmp/j1 | sort -u | head
grep -oE 'baseURL[^,;]{0,80}|API_BASE[^,;]{0,80}|VITE_[A-Z_]+' /tmp/j1 | sort -u | head -10
echo "=== endpoint matrix"
for base in /api/v1 /v1; do
  for p in /user/login /user/register /system/version /system/status /datasets /agents /chats; do
    c=$(curl -s -o /tmp/x -m 6 -w '%{http_code}' "$R$base$p")
    echo "GET $base$p -> $c $(head -c 100 /tmp/x | tr -d '\n')"
  done
done
echo "=== login/register POST"
for base in /api/v1 /v1; do
  echo "-- $base/user/login"
  curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"email":"admin@ragflow.io","password":"admin"}' "$R$base/user/login" -w '\n  %{http_code}\n' | head -c 300; echo
  echo "-- $base/user/register"
  curl -s -m 8 -X POST -H 'Content-Type: application/json' -d '{"nickname":"ul5685","email":"ul5685@probe.local","password":"Ul5685#Probe!2026"}' "$R$base/user/register" -w '\n  %{http_code}\n' | head -c 300; echo
done
echo "=== login page any version string"
curl -s -m 10 "$R/login" -o /tmp/lp -w 'lp %{http_code} %{size_download}\n'; grep -oE 'v0\.[0-9]+\.[0-9]+|version["=: ]+[0-9.]+' /tmp/lp | head
echo DONE
