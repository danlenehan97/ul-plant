echo "=== i94169 $(hostname) $(date -u) ==="
id
hostname
nvidia-smi -L
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
cat /etc/machine-id 2>/dev/null
hostname -I
uname -a
echo "=== end i94169 $(hostname) ==="
# r3 i94169
