echo "=== retest7360 $(hostname) $(date -u) nonce=R7360-234248 ==="
id
hostname
date -u
nvidia-smi -L | head -8
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
uname -srm
echo "=== end retest7360 nonce=R7360-234248 ==="
