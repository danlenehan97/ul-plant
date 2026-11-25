#!/bin/bash
set +e
echo "### RETRY $(date -u +%FT%TZ)"
chmod 600 keys2/k04_ibm_key.pem_ 2>/dev/null
OK=0
for i in $(seq 1 24); do
  R=$(timeout 20 ssh -i keys2/k04_ibm_key.pem_ -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o IdentitiesOnly=yes root@123.184.7.135 'echo OK' 2>&1 | tr -d '\r' | tail -1)
  echo "try$i: $R"
  case "$R" in *OK*) OK=1; break;; esac
  sleep 35
done
echo "AUTH_OK=$OK"
if [ "$OK" = "1" ]; then
  timeout 30 ssh -i keys2/k04_ibm_key.pem_ -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@123.184.7.135 'cat > /tmp/p5.sh' < vantage/p5.sh
  timeout 200 ssh -i keys2/k04_ibm_key.pem_ -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@123.184.7.135 'bash /tmp/p5.sh' 2>&1 | tail -c 60000
fi
echo "### END $(date -u +%FT%TZ)"
