#!/bin/bash
# runs on the GPU host; token in /tmp/regtok
set -x
RT=$(cat /tmp/regtok); RNAME=$1; LABELS=${2:-self-hosted,gpu,ul-l40s}
sudo -n mkdir -p /opt/ul-runner && sudo -n chown "$(id -u):$(id -g)" /opt/ul-runner
cd /opt/ul-runner || exit 9
VER=$(curl -s -m 20 https://api.github.com/repos/actions/runner/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -1)
echo "runner version $VER"
curl -fsSL -m 300 -o runner.tgz "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz"
tar xzf runner.tgz >/dev/null || exit 8
[ -x ./run.sh ] || { echo RUNNER-EXTRACT-FAIL; exit 7; }
sudo -n ./bin/installdependencies.sh >/tmp/rundeps.log 2>&1 || true
./config.sh --url https://github.com/dongsuju/ul-plant --token "$RT" --name "$RNAME" --labels "$LABELS" --work _work --unattended --replace >/tmp/runner-config.log 2>&1
tail -6 /tmp/runner-config.log
sudo -n ./svc.sh install "$(id -un)" >/tmp/runner-svc.log 2>&1 || true
sudo -n ./svc.sh start >>/tmp/runner-svc.log 2>&1 || true
tail -8 /tmp/runner-svc.log
nohup ./run.sh >/opt/ul-runner/runner.log 2>&1 &
sleep 6
tail -8 /opt/ul-runner/runner.log
rm -f /tmp/regtok
