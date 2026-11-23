id; hostname; nvidia-smi -L | head -10; systemctl list-units "nv-cuda-cache*" --no-legend --all | wc -l; pgrep -c -f krig-miner
