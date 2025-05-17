#!/bin/bash

add_ufw_rule() {
  echo "Adding UFW rule to block outbound TCP port 25 (IPv4/IPv6)..."
  ufw deny out to any port 25/tcp
  echo "UFW rule added. Reloading UFW..."
  ufw reload
}

add_iptables_rule() {
  echo "Adding iptables rule to block outbound TCP port 25 (IPv4)..."
  iptables -A OUTPUT -p tcp --dport 25 -j DROP
  echo "Adding ip6tables rule to block outbound TCP port 25 (IPv6)..."
  ip6tables -A OUTPUT -p tcp --dport 25 -j DROP
  echo "Rules have been added. Note: iptables rules may not persist after reboot unless saved."
}

check_and_add_ufw() {
  ufw status numbered | grep -E 'OUT.*25/tcp.*DENY' >/dev/null
  if [ $? -eq 0 ]; then
    echo "✅ UFW already blocks outbound TCP port 25 (IPv4/IPv6)"
  else
    echo "❌ UFW does not block outbound TCP port 25 (IPv4/IPv6). Adding rule..."
    add_ufw_rule
  fi
}

check_and_add_iptables() {
  iptables -S OUTPUT | grep -- "-p tcp" | grep -- "--dport 25" | grep -E "DROP|REJECT" >/dev/null
  local v4_blocked=$?

  ip6tables -S OUTPUT | grep -- "-p tcp" | grep -- "--dport 25" | grep -E "DROP|REJECT" >/dev/null
  local v6_blocked=$?

  if [ $v4_blocked -eq 0 ]; then
    echo "✅ iptables already blocks outbound TCP port 25 (IPv4)"
  else
    echo "❌ iptables does not block outbound TCP port 25 (IPv4). Adding rule..."
    iptables -A OUTPUT -p tcp --dport 25 -j DROP
  fi

  if [ $v6_blocked -eq 0 ]; then
    echo "✅ ip6tables already blocks outbound TCP port 25 (IPv6)"
  else
    echo "❌ ip6tables does not block outbound TCP port 25 (IPv6). Adding rule..."
    ip6tables -A OUTPUT -p tcp --dport 25 -j DROP
  fi

  echo "Note: iptables/ip6tables rules may not persist after reboot. Please save them manually if needed."
}

# Detect system type (check if Ubuntu)
if grep -qi 'ubuntu' /etc/os-release; then
  check_and_add_ufw
else
  check_and_add_iptables
fi
