echo "=== UL8357 PROBE $(date -u)"
id; hostname; uname -a
echo "--- nvidia"; (nvidia-smi -L 2>&1 | head -10); ls -l /dev/nvidia* 2>&1 | head -10
echo "--- proc"; ps -eo pid,args= 2>/dev/null | grep -Ei 'wildrig|peakminer|srbminer|plh|krig|keep' | grep -v grep | head -10
echo "--- sshd"; (ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null) | head -25
echo "PROBE-END"
