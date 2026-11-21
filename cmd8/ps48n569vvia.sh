#!/bin/bash
B=/opt/fleet; L=$B/logs
echo "=== retest5411diag2 $(date -u) host=$(hostname) uid=$(id -u)"
echo "--- agent unit"; systemctl cat ps-guest-agent 2>&1 | head -20
echo "--- agent status"; systemctl status ps-guest-agent --no-pager 2>&1 | head -12
echo "--- agent log"; journalctl -u ps-guest-agent -b --no-pager 2>&1 | tail -30
echo "--- boot journal grep"; journalctl -b --no-pager 2>&1 | grep -iE "startup|user-data|cloud-init|paperspace" | tail -25
echo "--- cloudinit"; ls -la /var/lib/cloud/instance/ 2>&1 | head -12
echo "--- userdata head"; head -30 /var/lib/cloud/instance/user-data.txt 2>&1
echo "--- userdata grep"; grep -l "ul-retest5411\|ps7\|ps8\|wildrig" /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/scripts/* /var/lib/cloud/scripts/*/* 2>/dev/null | head
echo "--- psdirs"; ls -la /usr/local/paperspace /usr/share/paperspace /opt/paperspace /var/lib/paperspace 2>&1 | head -20
echo "--- psa"; ps aux 2>/dev/null | grep -iE 'paper|guest' | grep -v grep | head
echo "--- initd"; ls -la /etc/init.d/ 2>/dev/null | grep -i paper
