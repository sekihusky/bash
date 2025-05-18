#!/bin/bash

add_ufw_rule() {
  echo "Adding UFW rules to block outbound TCP port 25 (IPv4/IPv6)..."

  # IPv4
  if ! ufw status | grep -qE '^(25|25/tcp)\s+DENY OUT'; then
    ufw deny out to any port 25 proto tcp || echo "Skipping adding rule (IPv4)"
  else
    echo "✅ UFW already has IPv4 rule for TCP port 25"
  fi

  # IPv6
  if ! ufw status | grep -qE '^(25|25/tcp)\s+DENY OUT.*\(v6\)'; then
    ufw deny out to any port 25 proto tcp comment 'Block SMTP IPv6' || echo "Skipping adding rule (IPv6)"
  else
    echo "✅ UFW already has IPv6 rule for TCP port 25"
  fi

  echo "Reloading UFW..."
  ufw reload
}

add_iptables_rule() {
  echo "Adding iptables/ip6tables rules to block outbound TCP port 25..."

  if ! iptables -C OUTPUT -p tcp --dport 25 -j DROP 2>/dev/null; then
    iptables -A OUTPUT -p tcp --dport 25 -j DROP
    echo "✅ Added iptables rule for IPv4"
  else
    echo "✅ iptables rule for IPv4 already exists"
  fi

  if ! ip6tables -C OUTPUT -p tcp --dport 25 -j DROP 2>/dev/null; then
    ip6tables -A OUTPUT -p tcp --dport 25 -j DROP
    echo "✅ Added ip6tables rule for IPv6"
  else
    echo "✅ ip6tables rule for IPv6 already exists"
  fi

  echo "⚠️ Note: iptables rules may not persist after reboot. Consider saving them if needed."
}

check_and_add_ufw() {
  local v4_rule
  local v6_rule

  v4_rule=$(ufw status | grep -E '^(25|25/tcp)\s+DENY OUT')
  v6_rule=$(ufw status | grep -E '^(25|25/tcp)\s+DENY OUT.*\(v6\)')

  if [[ -n "$v4_rule" && -n "$v6_rule" ]]; then
    echo "✅ UFW already blocks outbound TCP port 25 (IPv4/IPv6)"
  else
    echo "❌ UFW does not completely block outbound TCP port 25. Adding missing rules..."
    add_ufw_rule
  fi
}

check_and_add_iptables() {
  local v4_blocked=1
  local v6_blocked=1

  if iptables -C OUTPUT -p tcp --dport 25 -j DROP 2>/dev/null; then
    v4_blocked=0
  fi

  if ip6tables -C OUTPUT -p tcp --dport 25 -j DROP 2>/dev/null; then
    v6_blocked=0
  fi

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

  echo "⚠️ Note: iptables/ip6tables rules may not persist after reboot. Please save them manually if needed."
}

check_smtp_connection() {
  echo "Checking outbound connectivity to TCP port 25..."

  if ! command -v nc >/dev/null 2>&1; then
    echo "Installing 'nc' (netcat)..."
    if command -v apt >/dev/null 2>&1; then
      apt update && apt install -y netcat
    elif command -v yum >/dev/null 2>&1; then
      yum install -y nc
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y nc
    else
      echo "Unable to install netcat automatically. Please install it manually."
      return
    fi
  fi

  nc -vz smtp.gmail.com 25
}

# Detect system type
if grep -qi 'ubuntu' /etc/os-release; then
  check_and_add_ufw
else
  check_and_add_iptables
fi

# Optional: test connection
read -p "Do you want to test outbound TCP port 25 connectivity using nc? (y/N): " user_input
if [[ "$user_input" =~ ^[Yy]$ ]]; then
  check_smtp_connection
else
  echo "Skipping SMTP connectivity test."
fi
