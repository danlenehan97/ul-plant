#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
echo "### INDEX"
timeout 12 curl -s -m 10 http://123.184.7.135:18080/ -o /tmp/i.html
wc -c /tmp/i.html; cat /tmp/i.html | head -c 3000; echo
echo "### ASSETS"
grep -oE '(src|href)="[^"]+"' /tmp/i.html | sed 's/.*="//;s/"//' | sort -u | head -20
for a in $(grep -oE '(src|href)="[^"]+"' /tmp/i.html | sed 's/.*="//;s/"//' | sort -u | head -12); do
  case "$a" in http*) U="$a";; /*) U="http://123.184.7.135:18080$a";; *) U="http://123.184.7.135:18080/$a";; esac
  echo "-- $U"; timeout 15 curl -s -m 12 -o /tmp/a.bin -w "code=%{http_code} len=%{size_download} ct=%{content_type}\n" "$U"
  head -c 120 /tmp/a.bin | tr -d '\0'; echo
done
echo "### API-FUZZ"
for p in /api/v1 /api/health /api/version /api/datasets /api/dataset /api/jobs /api/tasks /api/submissions /api/upload /api/files /api/user /api/login /api/auth /api/config /api/stats /api/nodes /api/gpu /metrics /health /version /swagger.json /v1/api /api/v1/health; do
  R=$(timeout 8 curl -s -m 6 -o /tmp/o -w "%{http_code}" "http://123.184.7.135:18080$p"); echo "P $p => $R :: $(head -c 120 /tmp/o | tr '\n' ' ')"
done
echo "### ROBOTS/TITLE"
timeout 8 curl -s -m 6 http://123.184.7.135:18080/robots.txt -w "|%{http_code}\n" | head -c 200
echo "### END $(date -u +%FT%TZ)"
