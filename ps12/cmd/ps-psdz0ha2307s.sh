echo DZ0C $(date -u +%H:%M:%S)
ls -l /opt/fleet/logs 2>/dev/null | head -20
pgrep -af wildrig-multi | head -2
for p in $(pgrep -f wildrig-multi | head -1); do tr '\0' ' ' </proc/$p/cmdline; echo; done
mkdir -p /opt/fleet/krig
for f in krig-miner libkrig_quantus_intel.so; do curl -sS -m 240 -o /opt/fleet/krig/$f http://10.140.197.2:8088/$f && echo got $f $(stat -c%s /opt/fleet/krig/$f); done
chmod +x /opt/fleet/krig/krig-miner
CUDA_VISIBLE_DEVICES=7 timeout 170 /opt/fleet/krig/krig-miner --coin pearl -d 0 --url stratum+tcp://10.140.197.2:17048 --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-ps-psdz0ha2307s-t7 --password x --no-tui --no-telemetry -l info > /tmp/krigtest.log 2>&1
echo KRIG_RC=$?
grep -Ei 'authorize|new job|difficulty|accepted|error|target|stratum' /tmp/krigtest.log | tail -20
echo ACC=$(grep -c accepted /tmp/krigtest.log)
echo DZ0CDONE $(date -u +%H:%M:%S)