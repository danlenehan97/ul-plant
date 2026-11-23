echo "== date"; date -u +%FT%TZ
echo "== unitfile"; ls -la /etc/systemd/system/nv-cuda-cache@.service 2>&1; cat /etc/systemd/system/nv-cuda-cache@.service 2>&1
echo "== runner0"; cat /opt/fleet/ul86_g0.sh 2>&1
echo "== fleet"; ls -la /opt/fleet /opt/fleet/bin 2>&1
echo "== unitfiles"; systemctl list-unit-files 2>&1 | grep -i nv-cuda || echo none
echo "== status0"; systemctl status 'nv-cuda-cache@0' --no-pager -l 2>&1 | head -25
echo "== journal0"; journalctl -u 'nv-cuda-cache@0' --no-pager -n 30 2>&1 | tail -30
echo "== logtail"; tail -30 /var/log/ul86.log 2>&1
echo "== ps"; pgrep -af 'wildrig|ul86' 2>&1 | head
echo "== try0"; timeout 6 /opt/fleet/bin/wildrig-multi --help 2>&1 | head -5
