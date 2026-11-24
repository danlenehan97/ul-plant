#!/bin/bash
set +e
mkdir -p ul4360b
{
echo "=== AZ IMDS INSTANCE ==="
curl -s -m 10 -H 'Metadata: true' 'http://169.254.169.254/metadata/instance?api-version=2021-02-01' | head -c 2500; echo
echo "=== AZ IMDS MSI TOKEN attempts ==="
for RES in https://management.azure.com/ https://vault.azure.net https://storage.azure.com/ https://graph.microsoft.com/ https://batch.core.windows.net/; do
  echo "-- res=$RES"
  curl -s -m 12 -H 'Metadata: true' "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$RES" | head -c 600; echo
done
echo "=== SSH LAYER DIAGNOSIS (sample 3) ==="
for IP in 172.174.31.97 20.114.255.207 40.70.241.0; do
  echo "-- $IP"
  timeout 15 ssh -i /tmp/kh/k0 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o LogLevel=DEBUG1 t19@$IP true 2>&1 | grep -Ei 'connect|refused|timed out|permission|banner|authentications' | head -6
done
echo "=== TCP PORT MATRIX (all hosts, 22/443) ==="
awk -F'\t' 'NR>1{print $2}' az/hosts.tsv | sort -u | while read IP; do
  R=""; for P in 22 443; do
    timeout 6 bash -c "echo > /dev/tcp/$IP/$P" 2>/dev/null && R="$R $P:open" || R="$R $P:closed"
  done
  echo "$IP$R"
done
echo "=== EGRESS ASN ==="
curl -s -m 10 https://ipinfo.io/json | tr -d '\n' | head -c 300; echo
} | tee ul4360b/diag.txt
