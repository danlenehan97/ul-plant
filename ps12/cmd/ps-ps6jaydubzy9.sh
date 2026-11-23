#!/bin/bash
# ul87804 recon2: key deploy + ssh matrix on ps6
set -u
echo "=== recon2 $(date -u +%FT%TZ) host=$(hostname -s) ip=$(hostname -I|awk '{print $1}')"
K=/root/.ssh/ul86now
mkdir -p /root/.ssh; chmod 700 /root/.ssh
base64 -d > $K <<'B64'
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0egpjMmd0WldReU5UVXhPUUFBQUNDdWtITFVXODZFbkZXQTdLdmdHZ0QzUURxNTFMSTV6dm9qeG1OSTZxRU0yQUFBCkFJaU9hT0h0am1qaDdRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ3VrSExVVzg2RW5GV0E3S3ZnR2dEM1FEcTUKMUxJNXp2b2p4bU5JNnFFTTJBQUFBRUFaTk1kbldlcDdhZVBHUVovZnB2UjV0OWdVTllVNXYwR1p6RjAwQnhjeQpWcTZRY3RSYnpvU2NWWURzcStBYUFQZEFPcm5Vc2puTytpUEdZMGpxb1F6WUFBQUFBQUVDQXdRRgotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K
B64
chmod 600 $K
echo "== keyfp $(ssh-keygen -lf $K 2>&1 | head -1)"
echo "== sshd_effective"
grep -vE '^\s*#|^\s*$' /etc/ssh/sshd_config | head -30
ls /etc/ssh/sshd_config.d 2>/dev/null && cat /etc/ssh/sshd_config.d/*.conf 2>/dev/null | head -20
echo "== shadow"
awk -F: '{print $1":"$3":"substr($2,1,3)}' /etc/shadow 2>/dev/null | head -12
echo "== pskey"
ls -la /home/paperspace/.ssh 2>&1 | head -8
awk '{print substr($0,1,110)}' /home/paperspace/.ssh/authorized_keys 2>/dev/null | head -6
echo "== scan22"
for i in 2 3 4 5 6 7 8 9 10; do ( timeout 3 bash -c "echo > /dev/tcp/10.140.197.$i/22" 2>/dev/null && echo "10.140.197.$i:22 OPEN" || echo "10.140.197.$i:22 closed" ) & done; wait
echo "== ssh .8"
for u in root paperspace ubuntu; do echo "-- $u"; timeout 15 ssh -i $K -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 $u@10.140.197.8 'id; hostname; sudo -n true && echo SUDO-OK' 2>&1 | tail -4; done
echo "== done $(date -u +%FT%TZ)"
