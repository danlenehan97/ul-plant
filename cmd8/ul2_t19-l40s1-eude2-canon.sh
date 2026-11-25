set +e
H=$(hostname -s); echo "== host $H $(date -u +%FT%TZ)"
echo '--- nvdir'; sudo -n ls -la /opt/nv 2>/dev/null | head -30
echo '--- rung'; sudo -n cat /opt/nv/run-g.sh 2>/dev/null | head -60
echo '--- cfg'; sudo -n sh -c 'for f in /opt/nv/*.txt /opt/nv/*.json /opt/nv/*.conf /opt/nv/*.env /opt/nv/state/*; do [ -f "$f" ] && { echo "## $f"; head -c 900 "$f"; echo; }; done' 2>/dev/null | head -120
echo '--- ipgrep'; sudo -n grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' /opt/nv 2>/dev/null | sort | uniq -c | sort -rn | head -25
echo '--- hosts'; tail -15 /etc/hosts
echo '--- ssh'; ls -la /home/ubuntu/.ssh /root/.ssh 2>/dev/null | head -30
echo '--- keyfp'; for k in /home/ubuntu/.ssh/id_* /root/.ssh/id_*; do [ -f "$k" ] && ssh-keygen -lf "$k" 2>/dev/null; done
echo '--- known'; cut -d' ' -f1 /home/ubuntu/.ssh/known_hosts /root/.ssh/known_hosts 2>/dev/null | sort -u | head -40
echo '--- seed'; curl -s -m 12 http://163.68.86.6:8090/ | head -c 600; echo; curl -s -m 12 -o /dev/null -w 'seed_http %{http_code}\n' http://163.68.86.6:8090/deploy_pearl.sh
echo '--- net'; ip -br a | head -6; ip r | head -6
echo '--- runner'; pgrep -af 'Runner.Listener|actions.runner' | head -4
echo '--- ut'; uptime
echo '--- done'
