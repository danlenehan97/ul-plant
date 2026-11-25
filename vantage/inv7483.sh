set +e
echo "=== ID"; id; hostname; hostname -I; date -u; uname -a
echo "=== GPU"; nvidia-smi -L 2>&1
echo "=== SS"; ss -lntp 2>&1
echo "=== PS"; ps -eo pid,ppid,user,etimes,args= 2>&1 | head -120
echo "=== TIMERS"; systemctl list-timers --all --no-pager 2>&1 | head -40
echo "=== PLH_DIRS"; ls -la /usr/local/lib/.plh /etc/cron.d /opt/plh /root/.plh* /opt/plhllm 2>&1
echo "=== PLH_FILES"; for f in /usr/local/lib/.plh/guard.sh /etc/cron.d/plh /etc/cron.d/plh-keepalive /opt/plh/keep.sh /opt/plh/loop.sh /opt/plh/keepalive.sh; do echo "--- $f"; cat "$f" 2>&1 | head -60; done
echo "=== PLH_FIND"; find / -xdev \( -name '*plh*' -o -name '.plhm' \) -not -path '/proc/*' 2>/dev/null | head -80
echo "=== CRON"; crontab -l 2>&1; ls -la /var/spool/cron/crontabs 2>&1
echo "=== PORTS"; ss -lntp 2>&1 | grep -E ':1963|:19[0-9][0-9]|:1808[0-9]|:8099|:781'
echo "=== ENV_PLH"; env | grep -iE 'plh|pool|wallet|token|bucket|s3' 2>&1
echo "=== UNITS"; systemctl list-units --all --no-pager 2>&1 | grep -iE 'plh|ul|krig|miner|pearl' | head -40
echo "=== HOSTS"; cat /etc/hosts; ip -br a 2>/dev/null | head -10; ip r 2>/dev/null | head -10
echo "=== CONF"; ls -la /root/conf /root/ul2 /root/ul_plant 2>&1 | head -40
echo "=== DONE"
