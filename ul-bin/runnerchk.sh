#!/bin/bash
hostname; id
systemctl list-unit-files 'actions.runner.*' --no-pager 2>/dev/null | head -6
for f in /opt/ul-runner/.runner /opt/actions-runner/.runner /home/*/actions-runner/.runner; do [ -f "$f" ] && { echo "F=$f"; head -c 400 "$f"; echo; }; done
for u in $(systemctl list-unit-files 'actions.runner.*' --no-pager 2>/dev/null | awk '{print $1}' | grep '^actions'); do echo "START $u"; systemctl start "$u" 2>&1 | head -2; sleep 2; systemctl is-active "$u"; done
systemctl list-units 'actions.runner.*' --no-pager 2>/dev/null | head -6
