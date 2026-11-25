#!/bin/bash
# i8480 r2 - run on the self-hosted GPU runner (US): reachability to g0023 + ssh recon with ul5817 key
set +e
GH=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
R=https://raw.githubusercontent.com/dongsuju/ul-plant/main
W=/tmp/ul8480; mkdir -p $W
O=$W/i8480_out.txt; : > $O
say(){ echo "$*" >> $O; echo "$*"; }
H=$(hostname -s); say "=== i8480 r2 start $(date -u +%FT%TZ) host=$H uid=$(id -u) ip=$(curl -s -m 8 https://api.ipify.org 2>/dev/null)"
for p in 22 781 8099 9099 8000 11434 9100 18080 3306 6379; do
  timeout 4 bash -c "exec 3<>/dev/tcp/123.184.7.135/$p" 2>/dev/null && say "RUNNER_OPEN 123.184.7.135:$p" || say "RUNNER_CLOSED 123.184.7.135:$p"
done
curl -fsSL -m 40 -H "Authorization: token $GH" -H "Accept: application/vnd.github.raw" "$R/keys2/ul5817_key" -o $W/k || { say "KEY_FETCH_FAIL"; }
chmod 600 $W/k 2>/dev/null; ssh-keygen -y -f $W/k > $W/k.pub 2>/dev/null; say "KEY_PUB $(cut -c1-50 $W/k.pub)"
curl -fsSL -m 40 -H "Authorization: token $GH" -H "Accept: application/vnd.github.raw" "$R/vantage/gv8480/r1.sh" -o $W/r1.sh
OK=0
for t in 1 2 3; do
  if timeout 30 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes root@123.184.7.135 'id -u' 2>$W/e.txt; then say "PRECHECK_OK try=$t"; OK=1; break; fi
  say "PRECHECK_FAIL try=$t :: $(tail -1 $W/e.txt | cut -c1-160)"
  sleep 6
done
if [ "$OK" = 1 ]; then
  timeout 700 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes -o ServerAliveInterval=15 root@123.184.7.135 "TAG=r1 bash -s" < $W/r1.sh 2>&1 | tee -a $O
else
  say "--- ssh verbose tail"
  timeout 30 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes -v root@123.184.7.135 'id' 2>&1 | tail -25 | tee -a $O
  say "--- http probes from runner"
  for u in http://123.184.7.135:8099/seq http://123.184.7.135:9099/ http://123.184.7.135:8000/v1/models http://123.184.7.135:11434/api/tags; do
    say "GET $u -> $(timeout 12 curl -s -m 10 -o /tmp/ul8480/b -w '%{http_code}' "$u" 2>&1) body=$(head -c 200 /tmp/ul8480/b 2>/dev/null | tr '\n' ' ')"
  done
fi
say "=== i8480 r2 end $(date -u +%FT%TZ)"
b=$(base64 -w0 < $O); PTH="cmdout8/i8480_$H.txt"; B=https://api.github.com/repos/dongsuju/ul-plant/contents/$PTH
s=$(curl -s -m 20 -H "Authorization: token $GH" "$B?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
if [ -n "$s" ]; then J="{\"message\":\"i8480 r2 $H\",\"content\":\"$b\",\"sha\":\"$s\",\"branch\":\"main\"}"; else J="{\"message\":\"i8480 r2 $H\",\"content\":\"$b\",\"branch\":\"main\"}"; fi
curl -s -o /dev/null -w 'commit=%{http_code}\n' -m 30 -X PUT -H "Authorization: token $GH" -H "Content-Type: application/json" -d "$J" "$B"
cat $O
