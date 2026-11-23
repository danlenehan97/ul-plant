#!/bin/bash
# fix26: read-only census after fabric fix — who mines, with what argv, any accepted shares
echo "=== cmd $(date -u +%FT%TZ) host=$(hostname) uid=$(id -u)"
echo "== clock"; date -u; uptime
echo "== procs"
pgrep -af 'wildrig-multi|krig-miner|ps20|ps15|ps_sup|ultra' | grep -v pgrep | head -40
echo "== wrapper"
cat /opt/fleet/ps20_g0.sh 2>&1
echo "== wrappers-present"; ls -la /opt/fleet/*.sh 2>&1 | head -25
echo "== logs-recent"
find /opt/fleet /tmp /var/log -maxdepth 3 -name '*.log' -mmin -90 2>/dev/null | head -30
echo "== log-scan"
for f in $(find /opt/fleet /tmp -maxdepth 3 -name '*.log' -mmin -240 2>/dev/null | head -20); do
  a=$(grep -c 'accepted (' "$f" 2>/dev/null)
  echo "-- $f size=$(stat -c%s "$f" 2>/dev/null) accepted_lines=$a"
  grep 'accepted (' "$f" 2>/dev/null | tail -2
  tail -2 "$f" 2>/dev/null | cut -c1-200
done
echo "== smi"
nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw,temperature.gpu,memory.used --format=csv,noheader 2>&1
echo "== fm"
systemctl is-active nvidia-fabricmanager 2>&1; /usr/bin/nv-fabricmanager --version 2>&1
echo "== units"
systemctl list-units 'ul-*' 'nv-*' --no-pager --all 2>&1 | head -20
echo "== cron"
cat /etc/cron.d/* 2>/dev/null | grep -iE 'ul|ps|nv-' | head -10
echo "== DONE fix26 $(date -u +%FT%TZ)"
