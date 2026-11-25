#!/bin/bash
set +e
echo "=== KEEP $(date -u +%FT%TZ) host=$(hostname)"
echo "--- public ip"; curl -s -m 8 https://ifconfig.me; echo
echo "--- keep server"
for p in keep.sh keep9.sh index.html; do echo "== /$p"; curl -s -m 10 "http://163.68.86.6:8090/$p" | head -c 1200; echo; done
echo "== /"; curl -s -m 10 -i "http://163.68.86.6:8090/" | head -c 600; echo
echo "--- wire server"; curl -s -m 8 -H 'x-ms-version: 2012-11-30' "http://168.63.129.16/machine?comp=goalstate" | head -c 1500; echo
echo "--- local traces"; ps aux | grep -iE 'keep|watchdog' | grep -v grep | head -10
for f in /usr/local/bin/keep9.sh /opt/keep9.sh /root/keep9.sh; do [ -f "$f" ] && { echo "== $f"; sudo -n head -c 1500 "$f"; }; done
ls /etc/systemd/system | grep -iE 'keep|t19|nv' | head
echo "--- sshd config auth"; sudo -n grep -iE 'PasswordAuthentication|PermitRootLogin|AllowUsers' /etc/ssh/sshd_config 2>/dev/null | head -8
echo "=== KEEP END"
