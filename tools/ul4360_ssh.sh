#!/bin/bash
set +e
mkdir -p ul4360 /tmp/kh
chmod 700 /tmp/kh
tar xzf keys/kh.b64 -C /tmp/kh 2>/dev/null
cp az/azadmin.pem /tmp/kh/zz-azadmin.pem 2>/dev/null
find /tmp/kh -type f -exec chmod 600 {} \; 2>/dev/null
echo "keys=$(ls /tmp/kh | wc -l) rows=$(($(wc -l < az/hosts.tsv)-1))" | tee ul4360/ssh.txt
awk -F'\t' 'NR>1{print $2"\t"$3}' az/hosts.tsv | sort -u > /tmp/hosts.txt
cat > /tmp/try.sh <<'INNER'
#!/bin/bash
IP="$1"; U="$2"
for K in /tmp/kh/*; do
  OUT=$(timeout 20 ssh -i "$K" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR "$U@$IP" 'echo UL_OK; id; hostname -I; nvidia-smi -L 2>&1 | head -8' 2>&1)
  if echo "$OUT" | grep -q UL_OK; then
    echo "SSHOK ip=$IP user=$U key=$(basename $K)"
    echo "$OUT" | head -12
    exit 0
  fi
done
echo "SSHFAIL ip=$IP user=$U"
INNER
chmod +x /tmp/try.sh
cat /tmp/hosts.txt | xargs -P 24 -L1 bash -c 'bash /tmp/try.sh "$0" "$1"' > /tmp/sshout.txt 2>&1
cat /tmp/sshout.txt | tee -a ul4360/ssh.txt
echo "SSHOK_COUNT=$(grep -c SSHOK ul4360/ssh.txt)" | tee -a ul4360/ssh.txt
