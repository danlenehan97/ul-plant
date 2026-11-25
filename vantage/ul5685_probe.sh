#!/bin/bash
# i5685 step1: from root seat g0023 (123.184.7.135 / 192.168.0.23) map the VCC app plane
set +e
D=/dev/shm/ul5685/probe; mkdir -p $D
echo "=== BASELINE"
id; hostname; ip -br a 2>/dev/null | head -10; date -u
echo "=== IPS"
ip -4 -o addr show | awk '{print $2,$4}'
echo "=== ROUTES"
ip route | head -20
echo "=== ARP"
ip neigh | grep -E '192\.168\.0\.(2[0-9]|3[01])' | head -20

probe() { # host port path
  local h=$1 p=$2 path=$3
  local out="$D/${h}_${p}$(echo "$path" | tr '/?&=' '____').txt"
  timeout 6 curl -s -m 5 -D "$out.hdr" -o "$out" -w "HTTP %{http_code} len=%{size_download} t=%{time_total}\n" "http://$h:$p$path" 2>&1 > "$out.w"
  echo "--- $h:$p$path => $(cat $out.w 2>/dev/null) $(head -1 $out.hdr 2>/dev/null | tr -d '\r') $(grep -i '^server:' $out.hdr 2>/dev/null | tr -d '\r')"
  head -c 400 "$out" 2>/dev/null | tr -d '\000' | sed 's/^/    /'
  echo
}

for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  echo "########## $h"
  for path in / /api/health /api/jobs /api/submissions /api/datasets /api/status /docs /openapi.json /static/ /favicon.ico /api /robots.txt; do
    probe $h 18086 "$path"
  done
  for path in / /api/health /api/datasets /openapi.json; do
    probe $h 18080 "$path"
  done
done

echo "########## 781 metrics on .24"
probe 192.168.0.24 781 /metrics
echo "########## tcp connect matrix"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  for p in 18086 18080 781 9400 22 2375 10250 8265 8188 8000 8888 6443; do
    timeout 2 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null && echo "OPEN $h:$p" || true
  done
done

echo "=== FILESIZE"
du -sh $D; ls -la $D | head -5
echo "=== DONE"
