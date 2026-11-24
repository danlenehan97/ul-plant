#!/bin/bash
# NPA platform on g0023: node inventory / script exec / credentials
echo "=== ID"; hostname
echo "=== NPAENVFULL"
for c in npa-bicm npa-client-java npa-management-java; do echo "--- $c"; docker inspect $c --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | head -40; done
echo "=== MOUNTS"
for c in npa-bicm npa-client-java npa-management-java npa-nginx; do echo "--- $c"; docker inspect $c --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' 2>/dev/null | head -10; done
echo "=== NPAFILES"
for d in /ssd/vendors/*/npa* /ssd/npa* /data/npa* /opt/npa* /npa; do [ -e "$d" ] && { echo "--- $d"; ls -la "$d" 2>/dev/null | head -12; }; done
echo "=== SCRIPTLOG"; docker exec npa-bicm sh -c 'ls -la /logs/script 2>&1 | head -10; ls -la /data/npa-bicm 2>&1 | head -10' 2>&1 | head -25
echo "=== BICMCFG"; docker exec npa-bicm sh -c 'ls /app /opt 2>/dev/null | head; find / -maxdepth 3 -name "application*.yml" -o -maxdepth 3 -name "bootstrap*.yml" 2>/dev/null | head -5' 2>&1 | head -20
echo "=== MYSQL"
docker exec npa-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "show databases" 2>&1' | head -20
echo "=== MYSQLTABLES"
for db in $(docker exec npa-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "show databases" 2>/dev/null' | grep -viE 'information_schema|performance_schema|mysql|sys'); do
  echo "--- db $db"
  docker exec npa-mysql sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -N -e 'show tables' $db 2>/dev/null" | head -25
done
echo "=== HTTP"
for u in http://127.0.0.1:81/ http://127.0.0.1:18020/ http://127.0.0.1:18021/ http://192.168.0.20:8081/ http://127.0.0.1:18020/api/health http://127.0.0.1:18021/actuator  http://192.168.0.20:8081/api; do
  echo "--- $u"; timeout 8 curl -s -m 6 -o /tmp/h.$$ -w "%{http_code} %{size_download}\n" "$u" 2>&1; head -c 200 /tmp/h.$$ 2>/dev/null; echo; done
echo "=== IPMITOOL"; command -v ipmitool; ls -l /dev/ipmi* 2>&1 | head -3
echo "=== S20PROBE"
for p in 22 8081 80 443 3306 6379 9200 2375; do timeout 1 bash -c "echo > /dev/tcp/192.168.0.20/$p" 2>/dev/null && echo "open $p"; done
echo "=== DONE"
