echo "=== i94659 $(hostname) $(date -u) ==="
id
hostname
cat /etc/machine-id 2>/dev/null
nvidia-smi -L
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
hostname -I
uname -r
nproc
free -g | head -2
df -h / | tail -1
curl -s -m 6 https://ifconfig.me 2>/dev/null; echo
echo "=== end i94659 $(hostname) ==="
