#!/bin/bash
echo "=== ID"; hostname
for f in /root/conf/hostlist /root/conf/hosts /root/conf/hostname.sh /root/conf/change_hostname.sh /root/conf/install_all_1.sh /root/conf/install_all_2.sh; do
  echo "===FILE $f"; cat "$f" 2>&1 | head -c 3000; echo
done
echo "===PASSGREP"
timeout 30 grep -rnaE 'PASSWORD|passwd|sshpass|PASS=' /root/conf 2>/dev/null | cut -c1-200 | head -30
echo "===HISTPASS"
timeout 30 grep -naiE 'sshpass|PASSWORD=|ssh root@|ssh ubuntu@|scp .*@' /root/.bash_history 2>/dev/null | cut -c1-200 | head -40
echo "===ALLHOSTS"
timeout 30 sha256sum /root/conf/*.sh /root/conf/hostlist /root/conf/hosts 2>/dev/null | head -20
echo "=== DONE"
