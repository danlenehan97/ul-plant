#!/bin/bash
# INSPUR vendor platform on g0023: node credentials / management API
echo "=== ID"; hostname
echo "=== TREE"; ls -la /ssd/vendors/INSPUR 2>&1 | head -20
find /ssd/vendors/INSPUR -maxdepth 3 -type d 2>/dev/null | head -30
echo "=== DOCKER"; docker ps --format '{{.Names}}|{{.Image}}|{{.Ports}}' 2>&1 | head -20
echo "=== CONTAINER_MOUNTS"; docker inspect $(docker ps -q 2>/dev/null | head -6) 2>/dev/null | grep -E '"Name"|"Source"|"Destination"' | head -30
echo "=== GREPKEYS"
timeout 90 grep -rIlE 'BEGIN (OPENSSH|RSA) PRIVATE KEY' /ssd/vendors/INSPUR /root /etc /opt 2>/dev/null | head -10
echo "=== GREPCONF"
timeout 60 grep -riE 'vcc-worker|192\.168\.0\.2[0-9]|192\.168\.0\.3[01]' /ssd/vendors/INSPUR/project --include=*.py --include=*.json --include=*.yaml --include=*.yml --include=*.conf --include=*.ini --include=*.env --include=*.cfg 2>/dev/null | cut -c1-190 | head -25
echo "=== ENVFILES"; find /ssd/vendors/INSPUR -maxdepth 4 \( -name '.env' -o -name '*.env' -o -name 'config.py' -o -name 'settings.py' \) 2>/dev/null | head -10
for f in $(find /ssd/vendors/INSPUR -maxdepth 4 \( -name '.env' -o -name '*.env' \) 2>/dev/null | head -4); do echo "--- $f"; head -c 1200 "$f"; echo; done
echo "=== NGINXLOG"; tail -30 /ssd/vendors/INSPUR/nginx/logs/access.log 2>/dev/null | awk '{print $6,$7,$9}' | cut -c1-150 | sort | uniq -c | sort -rn | head -20
echo "=== ROUTES"
timeout 30 find /ssd/vendors/INSPUR/project -maxdepth 3 -name '*.py' 2>/dev/null | head -20
echo "=== ENDPOINTS"
timeout 60 grep -rhoE '@(app|router)\.(get|post|put|delete)\("[^"]+"' /ssd/vendors/INSPUR/project 2>/dev/null | sort -u | head -60
echo "=== EXECGREP"
timeout 60 grep -rniE 'subprocess|os\.system|paramiko|SSHClient|fabric|ansible|nvidia-smi|docker exec' /ssd/vendors/INSPUR/project --include=*.py 2>/dev/null | cut -c1-170 | head -25
echo "=== REDIS"; ls -la /ssd/vendors/INSPUR/redis 2>/dev/null | head; timeout 20 strings /ssd/vendors/INSPUR/redis/data/appendonlydir/*.aof 2>/dev/null | grep -aiE 'vcc-worker|192\.168\.0|passwd|token|ssh' | cut -c1-150 | head -15
echo "=== PORT8081"; timeout 10 curl -s -m 6 http://127.0.0.1:8081/ 2>&1 | head -c 300; echo; timeout 10 curl -s -m 6 http://127.0.0.1:8081/docs 2>&1 | head -c 200; echo; timeout 10 curl -s -m 6 http://192.168.0.20:8081/ 2>&1 | head -c 200; echo
echo "=== DONE"
