set +e
S="sudo -n"; H=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
WRK=ul-t2-ps-149-81-10-242-g0
echo "== t2i11443b $(date -u +%FT%TZ) host=$H boot=$(cat /proc/sys/kernel/random/boot_id) up=$(uptime -s)"
echo -n "wallet="; $S cat /opt/ul-t2/wallet; echo
echo "-- pm-run.sh before"; $S cat /opt/ul-t2/pm-run.sh
cat > /tmp/r.sh <<EOF
#!/bin/bash
exec /opt/nv/peakminer -d 0 -o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -o stratum+ssl://prl-eu.kryptex.network:8048 -o stratum+ssl://prl-us.kryptex.network:8048 -u "$W.$WRK" -p x -c pearl
EOF
$S install -m 755 /tmp/r.sh /opt/ul-t2/pm-run.sh
$S tee /opt/ul-t2/guard2.sh >/dev/null <<EOF
#!/bin/bash
if grep -q -- '--no-tui' /opt/ul-t2/pm-run.sh 2>/dev/null; then
  printf '#!/bin/bash\nexec /opt/nv/peakminer -d 0 -o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -u %s.%s -p x -c pearl\n' "$W" "$WRK" > /opt/ul-t2/pm-run.sh
  chmod 755 /opt/ul-t2/pm-run.sh
fi
pgrep -f "$WRK" >/dev/null || systemctl restart ul-t2-ps0
EOF
$S chmod 755 /opt/ul-t2/guard2.sh
$S sh -c '{ crontab -l 2>/dev/null | grep -v "ul-t2/guard2.sh"; echo "* * * * * /opt/ul-t2/guard2.sh"; echo "@reboot /opt/ul-t2/guard2.sh"; } | crontab -'
$S systemctl reset-failed ul-t2-ps0 2>/dev/null; $S systemctl restart ul-t2-ps0
sleep 30
echo "-- active"; $S systemctl is-active ul-t2-ps0; $S pgrep -fa "$WRK" | head -2 | cut -c1-200
echo "-- local"; curl -s -m 5 http://127.0.0.1:4068/summary | head -c 300; echo
echo "-- pool"
for i in $(seq 1 7); do
  R=$(curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr '{' '\n' | grep "\"worker\":\"$WRK\"")
  echo "try$i ${R:0:300}"
  case "$R" in *'"status":"online"'*) break;; esac
  sleep 12
done
$S tail -3 /opt/ul-t2/logs/ps0.log | cut -c1-160
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader
$S crontab -l | tail -3
echo done
