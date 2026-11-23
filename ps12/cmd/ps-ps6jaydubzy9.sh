#!/bin/bash
# fix27: krig share check + duplicate-generation census (read-only)
echo "=== cmd $(date -u +%FT%TZ) host=$(hostname)"
for g in 0 1 2 3 4 5 6 7; do
  f=/opt/fleet/logs/k-ps-ps6jaydubzy9-g$g.log
  echo "-- g$g size=$(stat -c%s $f 2>/dev/null) acc=$(grep -c 'accepted' $f 2>/dev/null)"
  grep -E 'accepted \(|Total:|authorized|new job' "$f" 2>/dev/null | tail -4
done
echo "== first-accepted-lines-all"
grep -h 'accepted' /opt/fleet/logs/k-*.log 2>/dev/null | tail -12
echo "== smi-procs"
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>&1 | head -30
echo "== krig-env"
P=$(pgrep -f 'krig-miner.*g0' | head -1); echo "pid=$P"; tr '\0' '\n' < /proc/$P/environ 2>/dev/null | grep -E 'CUDA_VISIBLE_DEVICES|PATH' | head -5
echo "== units-state"
systemctl is-active nv-cuda-cache@0 nv-cuda-cache@7 ul-prl@0 ul-prl@7 2>&1
echo "== sup-tail"
tail -8 /opt/fleet/logs/sup.log 2>&1
echo "== DONE fix27 $(date -u +%FT%TZ)"
