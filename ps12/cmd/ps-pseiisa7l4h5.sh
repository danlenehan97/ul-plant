#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); ts(){ date -u +%FT%TZ; }
echo "ts=$(ts) host=$H step=kxonly v89078"
for i in 0 1 2 3 4 5 6 7; do
  f=/opt/fleet/ul86_g$i.sh
  [ -f "$f.ph" ] || cp -a "$f" "$f.ph"
  cat > "$f" <<EOF
#!/bin/bash
exec /opt/fleet/bin/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d $i -o stratum+ssl://prl.kryptex.network:8048 -o stratum+tcp://prl.kryptex.network:7048 -u $W.ul-ps-$H-g$i -p x -i 8 --no-color >>/opt/fleet/logs/u86-g$i.log 2>&1
EOF
  chmod +x "$f"
  echo "=== ul89078 kxonly $(ts) ===" >> /opt/fleet/logs/u86-g$i.log
  systemctl restart nv-cuda-cache@$i
done
sleep 45
echo "--- selection g0"; tail -80 /opt/fleet/logs/u86-g0.log | grep -E "POOL #|use pool|authorize|error|new job|difficulty" | tail -14
for i in 0 1 2 3 4 5 6 7; do
  grep -c "accepted (" /opt/fleet/logs/u86-g$i.log > /tmp/ul_a$i
  echo "g$i sel=$(grep 'use pool' /opt/fleet/logs/u86-g$i.log | tail -1) acc0=$(cat /tmp/ul_a$i)"
done
sleep 130
echo "--- after $(ts)"
for i in 0 1 2 3 4 5 6 7; do
  a=$(grep -c "accepted (" /opt/fleet/logs/u86-g$i.log)
  a0=$(cat /tmp/ul_a$i)
  l=$(grep "accepted (" /opt/fleet/logs/u86-g$i.log | tail -1)
  hr=$(grep -oE "[0-9.]+ [TGM]H/s" /opt/fleet/logs/u86-g$i.log | tail -1)
  echo "g$i delta=$((a-a0)) acc_total=$a hr=$hr last=$l"
done
echo "--- err tail g0"; tail -120 /opt/fleet/logs/u86-g0.log | grep -iE "authorize|error|refused|closed|timeout|disconnect" | tail -6
echo "--- kxapi_hits:"; curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr ',' '\n' | grep -c pseiisa7l4h5
echo "END $(ts)"
