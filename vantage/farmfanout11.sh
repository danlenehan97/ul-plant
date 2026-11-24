#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START11 $(date -u +%FT%TZ)"
log "### PLH-SCRIPTS"
for f in /opt/plh/run_gpu.sh /opt/plh/keepalive.sh /opt/plh/c2fetch.sh /root/ul/actor/plh_keepalive.sh; do [ -f "$f" ] && { log "===== $f"; head -40 "$f"; }; done
log "### PLH-NEUTRAL"
timeout 20 grep -rIl 'plh' /etc/systemd/system /etc/cron* /var/spool/cron 2>/dev/null | head -10
pkill -f 'c2fetch' 2>/dev/null
mv /opt/plh /opt/plh.disabled.$(date +%s) 2>/dev/null && log "moved /opt/plh"
log "### HTTP-PROBE"
python3 - <<'PY'
import http.client,socket
def get(h,p,path="/",method="GET",body=None,timeout=4):
    try:
        c=http.client.HTTPConnection(h,p,timeout=timeout); c.request(method,path,body=body,headers={"Content-Type":"application/json"} if body else {})
        r=c.getresponse(); b=r.read(400); return f"{r.status} {b[:300]!r}"
    except Exception as e: return f"ERR {type(e).__name__} {e}"
targets=[("192.168.0.20",p) for p in (1900,1901,1907)]+[("192.168.0.21",p) for p in (1900,1907)]+[("192.168.0.22",p) for p in (14998,18000,18080)]+[("192.168.0.24",p) for p in (18080,18086)]
for h,p in targets:
    print("##",h,p)
    for path in ("/","/docs","/openapi.json","/v1/models","/health","/metrics"):
        print("  ",path,"->",get(h,p,path))
PY
log "### NFS-ALIAS"
ip addr add 192.168.0.31/32 dev bond0 2>&1 | head -2
sleep 2; ip -br a show bond0 | head -2
mkdir -p /mnt/uln1
for pair in "192.168.0.24:/ssd1" "192.168.0.24:/ssd2" "192.168.0.28:/ssd1" "192.168.0.30:/ssd1" "192.168.0.31:/ssd1"; do
  h=${pair%%:*}; ex=${pair#*:}
  umount /mnt/uln1 2>/dev/null
  if timeout 15 mount -t nfs -o rw,vers=3,nolock,soft,timeo=5 "$pair" /mnt/uln1 2>/tmp/e; then
    log "MOUNTED $pair"
    ls -la /mnt/uln1 2>&1 | head -12
    for d in /mnt/uln1/root/.ssh /mnt/uln1/home /mnt/uln1/etc/ssh /mnt/uln1/opt /mnt/uln1/data /mnt/uln1/containers /mnt/uln1/docker; do
      [ -e "$d" ] && { log "-- $d"; ls -la "$d" 2>&1 | head -10; }
    done
    echo probe > /mnt/uln1/.ul_probe_$(date +%s) 2>&1 && log "WRITE-OK $pair" || log "WRITE-RO $pair"
    umount /mnt/uln1 2>/dev/null
  else log "mountfail $pair :: $(head -1 /tmp/e)"; fi
done
ip addr del 192.168.0.31/32 dev bond0 2>&1 | head -2
log "### DONE11 $(date -u +%FT%TZ)"
