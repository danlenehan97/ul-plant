echo "=== i94169 agent-recon $(hostname) $(date -u) ==="
id
ps -eo pid,ppid,cmd | grep -Ei 'agent|sync|pull|beat|hb|watch' | grep -v grep | head -15
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -Ei 'agent|sync|fleet|hk|git' | head
ls -la /opt/fleet 2>/dev/null | head -15
find /opt /root /usr/local/bin /etc/systemd/system -maxdepth 2 \( -iname '*agent*' -o -iname '*sync*' -o -iname '*fleet*' \) 2>/dev/null | head -15
crontab -l 2>/dev/null
echo "=== end i94169 ==="
