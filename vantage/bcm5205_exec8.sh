#!/bin/bash
# exec8: reconcile/restore g0023 8x A800 canonical PRL miners
BIN=/opt/arsenal/miners/wildrig/wildrig-multi
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
POOL=prl-sg.kryptex.network:7048
echo "=== ID"; hostname; date -u
echo "=== HELP"; $BIN --help 2>&1 | tail -60
echo "=== UNITS"; systemctl list-units --all --no-pager 2>/dev/null | grep -iE 'prl|wildrig|ul-' | head -15
systemctl list-unit-files --no-pager 2>/dev/null | grep -iE 'prl|wildrig|ul-' | head -15
ls -la /root/ul /usr/local/bin/ul* /etc/systemd/system/*prl* 2>&1 | head -25
echo "=== CRON"; crontab -l 2>/dev/null | grep -iE 'prl|wildrig|ul-' | head -10
echo "=== TRY1"
mkdir -p /root/ul
cd /root/ul
rm -f t1.log
setsid nohup $BIN -a pearlhash -o $POOL -u $W.ul-t2-123-184-7-135-g0 -p x -d 0 --api-port 1960 > t1.log 2>&1 &
sleep 14
echo "alive: $(pgrep -fc 'wildrig.*1960')"
echo "--- t1.log"; tail -25 t1.log 2>/dev/null
echo "=== LAUNCH"
if pgrep -f 'wildrig.*1960' >/dev/null; then
  for i in 1 2 3 4 5 6 7; do
    if ! pgrep -f "wildrig.*api-port 196$i" >/dev/null; then
      setsid nohup $BIN -a pearlhash -o $POOL -u $W.ul-t2-123-184-7-135-g$i -p x -d $i --api-port 196$i > g$i.log 2>&1 &
      sleep 1
    fi
  done
  sleep 8
fi
echo "=== PS"; ps -eo pid,args | grep wildrig | grep -v grep | awk '{print $1, $11, $12, $13, $14, $15, $16, $17, $18}' | head -12
echo "=== PERSIST"
for i in 0 1 2 3 4 5 6 7; do
cat > /etc/systemd/system/ul-prl-g$i.service <<EOF
[Unit]
Description=ul prl g$i
After=network-online.target
[Service]
Type=simple
ExecStart=$BIN -a pearlhash -o $POOL -u $W.ul-t2-123-184-7-135-g$i -p x -d $i --api-port 196$i
Restart=always
RestartSec=30
Nice=10
WorkingDirectory=/root/ul
[Install]
WantedBy=multi-user.target
EOF
done
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do pkill -f "api-port 196$i" 2>/dev/null; done
sleep 2
for i in 0 1 2 3 4 5 6 7; do systemctl enable --now ul-prl-g$i.service >/dev/null 2>&1; done
sleep 6
systemctl is-active ul-prl-g0 ul-prl-g1 ul-prl-g2 ul-prl-g3 ul-prl-g4 ul-prl-g5 ul-prl-g6 ul-prl-g7 2>&1 | tr '\n' ' '; echo
cat > /usr/local/bin/ul-keep.sh <<'EOF'
#!/bin/bash
B=/opt/arsenal/miners/wildrig/wildrig-multi
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
for i in 0 1 2 3 4 5 6 7; do pgrep -f "api-port 196$i" >/dev/null || systemctl start ul-prl-g$i.service; done
EOF
chmod +x /usr/local/bin/ul-keep.sh
( crontab -l 2>/dev/null | grep -v 'ul-keep'; echo '@reboot /usr/local/bin/ul-keep.sh'; echo '*/5 * * * * /usr/local/bin/ul-keep.sh' ) | crontab -
grep -q 'ul-keep' /root/.bashrc || echo '/usr/local/bin/ul-keep.sh >/dev/null 2>&1' >> /root/.bashrc
echo "=== VERIFY"
ps -eo args | grep -c '[w]ildrig'
for i in 0 3 7; do echo "--- g$i"; journalctl -u ul-prl-g$i -n 6 --no-pager 2>/dev/null | tail -6; done
echo "=== POOLAPI"
timeout 20 curl -s -m 15 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr ',' '\n' | grep -iE '123-184-7-135|name|valid|hashrate' | head -30
echo "=== DONE"
