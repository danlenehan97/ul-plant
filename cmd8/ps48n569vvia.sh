#!/bin/bash
B=/opt/fleet; L=$B/logs
echo "=== retest5411diag $(date -u) host=$(hostname) uid=$(id -u)"
echo "--- bootlog"; ls -la /var/log/ul-retest-5411.log 2>&1; head -50 /var/log/ul-retest-5411.log 2>&1
echo "--- psunits"; systemctl list-units --all 2>/dev/null | grep -iE 'paper|gradient|startup' | head -10
echo "--- psfiles"; ls -la /etc/paperspace /opt/paperspace /var/lib/paperspace /var/lib/paperspace* 2>&1 | head -25
echo "--- unitgrep"; grep -rlE 'ul-retest5411|startup' /etc/systemd/system /lib/systemd/system 2>/dev/null | head -10
echo "--- svc"; systemctl is-active paperspace-agent 2>&1; systemctl is-active gradient-agent 2>&1
echo "--- ps8cfg"; ls -la $B/ps8_install.sh $B/state 2>&1 | head
echo "--- uptime"; uptime; who -b 2>&1
