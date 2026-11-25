#!/bin/bash
set +e
echo "### START $(date -u +%FT%TZ)"
for u in "http://123.184.7.135:18080/" "http://123.184.7.135:18080/api/health" "http://123.184.7.135:18080/api/datasets" "http://123.184.7.135:18080/docs" "http://123.184.7.135:18080/openapi.json"; do
  echo "-- $u"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" "$u"; head -c 300 /tmp/o; echo
done
echo "-- .130:80"; timeout 10 curl -s -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" http://123.184.7.130/; head -c 200 /tmp/o; echo
echo "-- .130:443"; timeout 10 curl -sk -m 8 -o /tmp/o -w "code=%{http_code} len=%{size_download}\n" https://123.184.7.130/; head -c 200 /tmp/o; echo
echo "### DCGM"
for ip in 123.184.7.129 123.184.7.179 123.184.7.135; do
  echo "-- $ip:9400"; timeout 12 curl -s -m 10 "http://$ip:9400/metrics" -o /tmp/d -w "code=%{http_code} len=%{size_download}\n"
  grep -E "^DCGM_FI_DEV_(GPU_NAME|MEMORY_TOTAL)|^DCGM_FI_DRIVER_VERSION" /tmp/d 2>/dev/null | head -4
  grep -c "^DCGM_FI_DEV_GPU_TEMP" /tmp/d 2>/dev/null
  grep -oE 'Hostname="[^"]*"' /tmp/d 2>/dev/null | sort -u | head -3
done
echo "### END $(date -u +%FT%TZ)"
