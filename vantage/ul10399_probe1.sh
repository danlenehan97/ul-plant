#!/bin/bash
set +e
echo "== META $(date -u +%FT%TZ)"
id; hostname; hostname -I; uname -a
echo "== GPU"
nvidia-smi -L 2>&1 | head -12
echo "== HUB DIR"
ls -la /opt/t19/www 2>&1 | head -80
echo "== ACC SIZE"
wc -l /opt/t19/www/access.log 2>/dev/null; du -h /opt/t19/www/access.log 2>/dev/null
echo "== LISTEN 8099"
ss -ltnp 2>/dev/null | grep ':8099' || echo NO8099
ps -eo pid,args 2>/dev/null | grep -Ei 'http.server|srv_i7448|srv2|dl_srv|SimpleHTTP' | grep -v grep | head
echo "== T19 UNITS"
systemctl list-units --all --no-pager 2>/dev/null | grep -iE 't19|plh|ul' | head -30
echo "== UP DIR"
ls -la /opt/t19/www/up 2>/dev/null | head -80
echo "== REQUESTS BY NODE"
for ip in 192.168.0.20 192.168.0.23 192.168.0.24 192.168.0.28 192.168.0.29 192.168.0.30 192.168.0.31 127.0.0.1; do
  n=$(grep -c "^$ip " /opt/t19/www/access.log 2>/dev/null)
  echo "--- $ip count=$n"
  grep "^$ip " /opt/t19/www/access.log 2>/dev/null | awk '{print $2,$3,$4}' | sort | uniq -c | sort -rn | head -10
done
echo "== ALL GET sh"
awk '{print $1,$2,$3,$4}' /opt/t19/www/access.log 2>/dev/null | grep -E '\.sh' | sort | uniq -c | sort -rn | head -50
echo "== ALL UP POST"
grep ' POST /up/' /opt/t19/www/access.log 2>/dev/null | awk '{print $1,$2,$3}' | sort | uniq -c | sort -rn | head -50
echo "== ARP NEIGH"
ip neigh 2>/dev/null | head -30
echo "== ROUTES"
ip -br a 2>/dev/null | head -10
echo "== ENDPROBE"
