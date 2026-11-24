#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START5 $(date -u +%FT%TZ)"
log "### BCM-TREE"; find /opt/bcm-agent -maxdepth 3 2>/dev/null | head -60
log "### BCM-CONF"; for f in /opt/bcm-agent/conf/* /opt/bcm-agent/etc/*; do [ -f "$f" ] && { log "===== $f"; head -40 "$f"; }; done
log "### BCM-LOG"; ls -la /opt/bcm-agent/log 2>/dev/null | head; tail -20 /opt/bcm-agent/log/*.log 2>/dev/null | head -40
log "### BCM-PROC"; ps -eo pid,args 2>/dev/null | grep -i bcm | grep -v grep | head -5
log "### NPA-APP"
systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE 'npa|inspur|bicm|hosteye|dcgm|node_exporter' | head -12
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' 2>&1 | head -20
lxc list 2>&1 | head -12
log "### NPA-CONF"
timeout 40 grep -rIl --include='*.conf' --include='*.yml' --include='*.yaml' --include='*.json' --include='*.ini' --include='*.toml' -E 'vcc-worker|192\.168\.0\.(24|28|30|31)' /opt /etc /ssd /data /root /usr/local 2>/dev/null | head -15
log "### P8081"
python3 - <<'PY'
import socket,ssl,http.client
hosts=["192.168.0.20","192.168.0.21","192.168.0.22","192.168.0.24","192.168.0.28","192.168.0.30","192.168.0.31"]
ports=[80,443,3000,8080,8081,8082,8083,8085,8443,9090,9091,9200,3306,6379,5601,9000]
for h in hosts:
    for p in ports:
        try:
            s=socket.create_connection((h,p),1.2); s.close(); print("OPEN",h,p,flush=True)
        except Exception: pass
PY
log "### HTTP-8081"
for h in 192.168.0.20 192.168.0.21 192.168.0.22 192.168.0.24; do
  for u in "http://$h:8081/" "https://$h:8081/" "http://$h:8081/api/v1/version" "http://$h:8081/healthz"; do
    log "-- $u"; timeout 6 curl -sk -m 5 -o /tmp/b -w "http=%{http_code} len=%{size_download} " "$u" 2>&1; head -c 200 /tmp/b 2>/dev/null; echo
  done
done
log "### BCM-CMDAEMON-PROBE"
timeout 8 openssl s_client -connect 192.168.0.20:8081 -servername 192.168.0.20 </dev/null 2>&1 | grep -E 'subject=|issuer=|Protocol|Cipher' | head -5
log "### DONE5 $(date -u +%FT%TZ)"
