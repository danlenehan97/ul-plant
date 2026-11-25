#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### :80-BODY"
timeout 12 curl -s -m 10 http://123.184.7.135/ -o /tmp/i80.html -w "code=%{http_code} len=%{size_download}\n"
grep -aoE "code-server|vscode|openvscode|theia|jupyter|monaco|workbench|folder|workspaceId|/stable-[a-f0-9]+" /tmp/i80.html | sort | uniq -c | head -12
head -c 1200 /tmp/i80.html; echo
grep -oE '(src|href)="[^"]+"' /tmp/i80.html | sort -u | head -12
echo "### :80-EP"
for p in /healthz /api/healthz /version /login /favicon.ico /static/out/vs/code/browser/workbench/workbench.html /vscode-remote-resource /api/v1/health /robots.txt; do
  echo "P $p => $(timeout 8 curl -s -m 6 -o /tmp/o -w '%{http_code}' http://123.184.7.135$p) :: $(head -c 100 /tmp/o|tr '\n' ' ')"
done
echo "### :443-APP"
timeout 12 curl -sk -m 10 https://123.184.7.135/ -o /tmp/i43.html -w "code=%{http_code} len=%{size_download}\n"
grep -oE '(src|href)="[^"]+"' /tmp/i43.html | sort -u | head -10; grep -aoE "<title>[^<]*" /tmp/i43.html
for p in /api/health /api/version /login /health /docs /api/v1/health; do
  echo "S $p => $(timeout 8 curl -sk -m 6 -o /tmp/o -w '%{http_code}' https://123.184.7.135$p) :: $(head -c 100 /tmp/o|tr '\n' ' ')"
done
echo "### RAGFLOW-REG"
B=http://123.184.7.135:18080
for p in /api/v1/auth/register /api/v1/auth/signup /api/v1/auth/user/register /api/v1/auth/join /api/v1/auth/new_user /api/v1/user/create /api/v1/auth/sso /api/v1/auth/password/reset; do
  R=$(timeout 8 curl -s -m 6 -X POST -o /tmp/o -w "%{http_code}" "$B$p" -H 'Content-Type: application/json' -d '{"email":"ul5512@ul.local","password":"Ul5512!pass","nickname":"ul5512"}')
  echo "POST $p => $R :: $(head -c 160 /tmp/o|tr '\n' ' ')"
done
echo "### END $(date -u +%FT%TZ)"
