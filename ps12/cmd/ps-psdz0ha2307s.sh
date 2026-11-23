echo KX2START $(date -u +%H:%M:%S)
CUDA_VISIBLE_DEVICES=7 timeout 420 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://10.140.197.2:18048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-ps-psdz0ha2307s-g7 --password x --no-tui --no-telemetry -l info > /tmp/krigtest2.log 2>&1
echo RC=$?
grep -Ei 'connected|authorize|new job|difficulty|accepted|error|share' /tmp/krigtest2.log | tail -30
echo ACCEPTED=$(grep -c accepted /tmp/krigtest2.log)
echo KX2DONE $(date -u +%H:%M:%S)