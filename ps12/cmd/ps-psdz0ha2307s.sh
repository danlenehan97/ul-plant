echo KX3START $(date -u +%H:%M:%S)
CUDA_VISIBLE_DEVICES=7 timeout 360 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://10.140.197.2:18048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-ps-psdz0ha2307s-g7 --password x --no-tui --no-telemetry -l info > /tmp/krigtest3.log 2>&1
echo RC=$?
grep -Ei 'accepted|reject|error|invalid|authorize|Total:' /tmp/krigtest3.log | tail -25
echo ACC=$(grep -c accepted /tmp/krigtest3.log) REJ=$(grep -ci reject /tmp/krigtest3.log)
echo KX3DONE $(date -u +%H:%M:%S)