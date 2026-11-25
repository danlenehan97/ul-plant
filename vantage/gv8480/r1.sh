echo "UL8480 $(date -u +%FT%TZ) TAG=$TAG"
id
hostname
uname -a
echo "---ip"
ip -br a
echo "---route"
ip route
echo "---neigh"
ip neigh
echo "---hosts"
cat /etc/hosts
echo "---probe"
for t in 172.16.10.1 172.16.10.11 172.16.10.20 172.16.10.71 172.16.10.76 172.16.10.254 172.16.11.1 172.16.21.11 172.16.21.34 172.16.21.35 10.80.80.12 10.80.80.13 10.80.80.14; do
  for p in 22 443 3389 5985 2375 9400; do
    if timeout 3 bash -c "exec 3<>/dev/tcp/$t/$p" 2>/dev/null; then echo "OPEN $t:$p"; else echo "CLOSED $t:$p"; fi
  done
done
echo "---nvidia"
nvidia-smi -L 2>&1 | head -10
echo "---done"
