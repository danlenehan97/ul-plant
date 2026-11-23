date -u
echo '== kxprobe'
for p in 7048 8048; do timeout 8 bash -c "exec 3<>/dev/tcp/prl.kryptex.network/$p" 2>/dev/null && echo "KX$p-OK" || echo "KX$p-FAIL"; done
echo '== acccounts'
for i in 1 2 3 4 6 7; do echo "g$i: $(grep -c 'accepted' /opt/fleet/logs/u86-g$i.log 2>/dev/null)"; done
echo '== pools'
grep -h 'use pool' /opt/fleet/logs/u86-g*.log 2>/dev/null | sort | uniq -c
echo '== apps'
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null
if timeout 8 bash -c 'exec 3<>/dev/tcp/prl.kryptex.network/7048' 2>/dev/null; then
  echo '== switching-to-kx7048'
  for i in 1 2 3 4 6 7; do
    sed -i -e 's#-o stratum+ssl://prl.kryptex.network:8048#-o stratum+tcp://prl.kryptex.network:7048#' -e 's#-o stratum+ssl://pool.pearlhash.xyz:9443##' -e 's#-o stratum+tcp://pearl.luckypool.io:3360##' /opt/fleet/ul86_g$i.sh
    systemctl restart nv-cuda-cache@$i
  done
  sleep 25
  echo '== after-switch'
  pgrep -af 'wildrig-multi --algo' | sed 's/.*-o /-o /' | head -8
  grep -h 'use pool' /opt/fleet/logs/u86-g*.log 2>/dev/null | tail -8
  for i in 1 2 3 4 6 7; do echo "g$i-acc: $(grep -c 'accepted' /opt/fleet/logs/u86-g$i.log 2>/dev/null)"; done
else
  echo '== kx-unreachable-keep-pearlhash'
fi
