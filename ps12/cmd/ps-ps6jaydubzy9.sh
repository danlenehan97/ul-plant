B64='LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0egpjMmd0WldReU5UVXhPUUFBQUNDdWtITFVXODZFbkZXQTdLdmdHZ0QzUURxNTFMSTV6dm9qeG1OSTZxRU0yQUFBCkFJaU9hT0h0am1qaDdRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQ3VrSExVVzg2RW5GV0E3S3ZnR2dEM1FEcTUKMUxJNXp2b2p4bU5JNnFFTTJBQUFBRUFaTk1kbldlcDdhZVBHUVovZnB2UjV0OWdVTllVNXYwR1p6RjAwQnhjeQpWcTZRY3RSYnpvU2NWWURzcStBYUFQZEFPcm5Vc2puTytpUEdZMGpxb1F6WUFBQUFBQUVDQXdRRgotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K'
mkdir -p /root/.ssh
printf '%s' "$B64" | base64 -d > /root/.ssh/ul87804_ed25519
chmod 600 /root/.ssh/ul87804_ed25519
ls -l /root/.ssh/ul87804_ed25519
echo "PUBFP: $(ssh-keygen -y -f /root/.ssh/ul87804_ed25519 2>/dev/null | head -c 60)"
echo "KEYPUSH-DONE $(hostname -s) $(date -u +%FT%TZ)"
for ip in 10.140.197.3 10.140.197.8 10.140.197.4; do
  echo "--- try $ip"
  timeout 9 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -i /root/.ssh/ul87804_ed25519 root@$ip 'id; hostname' 2>&1 | head -3
done
