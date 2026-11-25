#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### ID $(hostname) $(date -u +%FT%TZ)"
log "### IPBR"; ip -br a 2>&1
log "### IPLINK"
ip -d link 2>&1 | head -160
log "### ROUTES-ALL"; ip route show table all 2>&1 | head -60
log "### RULES"; ip -4 rule show 2>&1
log "### NEIGH"; ip neigh 2>&1 | head -50
log "### ARP"; arp -an 2>&1 | head -30
log "### VLANCONF"; cat /proc/net/vlan/config 2>&1
log "### SYSCONFIG"
ls -la /etc/sysconfig/network-scripts/ 2>&1 | head -40
ls -la /etc/netplan/ /etc/NetworkManager/system-connections/ 2>&1 | head -20
log "### IFCFG"
grep -rniE 'vlan|VLAN_ID|172\.16|DEVICE=|BOOTPROTO|IPADDR' /etc/sysconfig/network-scripts/ 2>/dev/null | head -60
log "### ETHTOOL"
for i in $(ls /sys/class/net 2>/dev/null); do
  echo "--- $i oper=$(cat /sys/class/net/$i/operstate 2>/dev/null) mtu=$(cat /sys/class/net/$i/mtu 2>/dev/null)"
  ethtool -i "$i" 2>&1 | head -5
  ethtool "$i" 2>&1 | grep -E 'Speed|Duplex|Link detected'
done
log "### LSPCI"; lspci -nn 2>/dev/null | grep -iE 'ethernet|network'
log "### BOND"; cat /proc/net/bonding/* 2>/dev/null | head -20
log "### CM-CONF"
for f in /etc/cm.conf /cm/local/apps/cmd/etc/cmd.conf /etc/cm/*.conf /etc/cm/*.xml; do
  [ -f "$f" ] && { echo "--- $f"; grep -inE 'vlan|network|172\.16|subnet|interface|eth[0-9]|headnode|external' "$f" 2>/dev/null | head -40; }
done
log "### CMDIR"; ls /cm/local/apps/cmd/etc/ 2>&1 | head -20
log "### CMSH"; timeout 25 cmsh -c "network; list" 2>&1 | head -40
log "### CMSH2"; timeout 25 cmsh -c "device; list" 2>&1 | head -30
log "### HOSTS"; cat /etc/hosts 2>&1
log "### SSHLISTEN"; ss -lntp 2>&1 | head -40
log "### IPADDR"; ip -4 addr show 2>&1 | grep -E 'inet |^[0-9]'
log "### DONE"
