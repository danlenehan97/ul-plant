#!/bin/bash
# exec11: remove my duplicate units/hooks, verify original ul-g plant intact
echo "=== ID"; hostname; date -u
echo "=== CRON_BEFORE"; crontab -l 2>/dev/null
crontab -l 2>/dev/null | grep -v 'ul-keep' | crontab - 2>/dev/null
sed -i '/ul-keep/d' /root/.bashrc 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl disable --now ul-prl-g$i >/dev/null 2>&1; rm -f /etc/systemd/system/ul-prl-g$i.service; done
rm -f /usr/local/bin/ul-keep.sh
systemctl daemon-reload
echo "=== CRON_AFTER"; crontab -l 2>/dev/null
echo "=== UNITS"; systemctl is-active ul-g0 ul-g1 ul-g2 ul-g3 ul-g4 ul-g5 ul-g6 ul-g7 2>&1 | tr '\n' ' '; echo
ls /etc/systemd/system/ | grep -iE 'ul-|prl' | head -15
echo "=== GUARDLOG"; journalctl -u ul-guard -n 5 --no-pager 2>/dev/null | tail -5
echo "=== MINER"; journalctl -u ul-g0 -n 4 --no-pager 2>/dev/null | tail -4
echo "=== COUNT"; pgrep -fc wildrig; pgrep -fa wildrig 2>/dev/null | head -2 | cut -c1-120
echo "=== DONE"
