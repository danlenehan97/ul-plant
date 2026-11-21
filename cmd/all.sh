#!/bin/bash
# fleet command: rewrite supervisor (intensity ladder + no spurious pool rotation), relaunch miners, push kit to blob
set -u
B=/opt/fleet/bin; L=/opt/fleet/logs
P=$(cat /opt/fleet/prefix 2>/dev/null)
echo "=== cmd all $(date -u) on $P uid=$(id -u)"
SAS='sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
BLOB="https://ulbatchkit4620.blob.core.windows.net/kit/wildrig-multi?$SAS"
SZ=$(stat -c%s "$B/wildrig-multi" 2>/dev/null || echo 0)
echo "bin size=$SZ"
if [ "$SZ" -gt 20000000 ] && [ ! -f "$B/blob_up" ]; then
  c=$(curl -s -m 300 -X PUT -H 'x-ms-blob-type: BlockBlob' -H 'Content-Type: application/octet-stream' --data-binary @"$B/wildrig-multi" "$BLOB" -o /dev/null -w '%{http_code}')
  echo "blob put=$c"
  [ "$c" = 201 ] && touch "$B/blob_up"
fi
[ -f /opt/fleet/margs ] || echo "--gpu-intensity 6" > /opt/fleet/margs

cat > "$B/ps_sup.sh" <<'SUP'
#!/bin/bash
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
P=$(cat /opt/fleet/prefix 2>/dev/null); L=/opt/fleet/logs; B=/opt/fleet/bin
exec 9>"$B/ps_sup.lock"; flock -n 9 || exit 0
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -eq 0 ] && N=1
POOLS=("stratum+ssl://prl.kryptex.network:8048" "stratum+tcp://prl.kryptex.network:7048" "stratums://pool.pearlhash.xyz:9443" "stratum+tcp://pearl.luckypool.io:3360")
pi=0; [ -f "$B/ps_pool_idx" ] && pi=$(cat "$B/ps_pool_idx" 2>/dev/null || echo 0)
log() { echo "[$(date -u +%H:%M:%S)] $*" >> "$L/logs/sup.log"; }
[ -x "$B/wildrig-multi" ] || "$B/ps_kit.sh"
start_ts=$(date +%s)
while true; do
  if [ ! -x "$B/wildrig-multi" ]; then log "no bin"; "$B/ps_kit.sh"; sleep 30; continue; fi
  url=${POOLS[$pi]}
  for i in $(seq 0 $((N-1))); do
    if ! pgrep -f "ul-$P-g$i" >/dev/null 2>&1; then
      # intensity ladder: per-gpu override -> fleet default
      if [ -f "$B/margs.g$i" ]; then MA=$(cat "$B/margs.g$i"); else MA=$(cat /opt/fleet/margs 2>/dev/null); fi
      setsid "$B/wildrig-multi" --algo pearlhash --url "$url" --user "$W.ul-$P-g$i" --pass x -d $i $MA >> "$L/logs/w-$P-g$i.log" 2>&1 &
      log "start g$i $url args[$MA]"
      sleep 2
    fi
  done
  sleep 40
  alive=0
  for i in $(seq 0 $((N-1))); do
    if pgrep -f "ul-$P-g$i" >/dev/null 2>&1; then
      alive=$((alive+1))
      # OOM ladder per gpu
      if tail -25 "$L/logs/w-$P-g$i.log" 2>/dev/null | grep -q 'out of memory'; then
        cur=$(cat "$B/margs.g$i" 2>/dev/null || cat /opt/fleet/margs 2>/dev/null | grep -oE '[0-9]+')
        nxt=$(( ${cur:-6} / 2 )); [ "$nxt" -lt 1 ] && nxt=1
        echo "--gpu-intensity $nxt" > "$B/margs.g$i"
        log "g$i OOM -> intensity $nxt"
        pkill -9 -f "ul-$P-g$i"
      fi
    fi
  done
  acc=$(grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | wc -l)
  if [ "$alive" -eq 0 ]; then
    fails=$(( $(cat "$B/ps_fail" 2>/dev/null || echo 0) + 1 )); echo "$fails" > "$B/ps_fail"
    log "alive=0 fail=$fails acc=$acc"
    if [ "$fails" -ge 3 ]; then
      pi=$(( (pi+1) % 4 )); echo "$pi" > "$B/ps_pool_idx"; echo 0 > "$B/ps_fail"
      log "rotate pool -> ${POOLS[$pi]}"
      for i in $(seq 0 $((N-1))); do pkill -9 -f "ul-$P-g$i" 2>/dev/null; done
      sleep 2
    fi
  else
    echo 0 > "$B/ps_fail"
    now=$(date +%s)
    if [ "$acc" -eq 0 ] && [ $((now-start_ts)) -gt 1500 ] && [ ! -f "$B/ps_rotated" ]; then
      pi=$(( (pi+1) % 4 )); echo "$pi" > "$B/ps_pool_idx"; touch "$B/ps_rotated"
      log "no shares in 25min -> rotate pool ${POOLS[$pi]}"
      for i in $(seq 0 $((N-1))); do pkill -9 -f "ul-$P-g$i" 2>/dev/null; done
    fi
  fi
done
SUP
chmod +x "$B/ps_sup.sh"
pkill -9 -f 'ps_sup.sh' 2>/dev/null
sleep 1
for p in $(pgrep -f "ul-$P-g" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
setsid nohup "$B/ps_sup.sh" >/dev/null 2>&1 &
sleep 20
echo "--- sup tail"; tail -6 "$L/logs/sup.log" 2>/dev/null
echo "--- procs"; pgrep -af 'wildrig-multi' | head -12
echo "--- g0 tail"; tail -8 "$L/logs/w-$P-g0.log" 2>/dev/null
echo "=== cmd done $(date -u)"
