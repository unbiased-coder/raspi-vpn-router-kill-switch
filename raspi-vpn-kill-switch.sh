#!/bin/bash

clear

if [ "$#" -ne 1 ]; then
    echo "$0 <interface name>"
    exit -1
fi

IFACE=$1
echo "Using interface: $1"

echo "Killing previous instances of openvpn"
killall -9 openvpn

echo "Flushing iptables rules" 
iptables -F 
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

echo "Current IP: `curl -s ifconfig.co`"

# temporarily block forwarding so nothing leaks if we restart this script
sysctl -w net.ipv4.ip_forward=0

# allow ssh
echo "Allowing incoming/outgoing SSH established on all interfaces" 
iptables -A INPUT -p tcp --dport 22 -j ACCEPT 
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

echo "Allowing DHCP traffic"
iptables -A INPUT -j ACCEPT -p udp --dport 67:68 --sport 67:68
iptables -A OUTPUT -j ACCEPT -p udp --dport 67:68 --sport 67:68

echo "Allowing traffic on lo"
iptables -A OUTPUT -j ACCEPT -o lo
iptables -A INPUT -j ACCEPT -i lo

echo "Allowing traffic on tun"
iptables -A OUTPUT -j ACCEPT -o tun+
iptables -A INPUT -j ACCEPT -i tun+

# allow traffic from established connections
echo "Allowing already established traffic"
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# allow openvpn uid, we need this prior we run openvpn because openvpn drops permissions at the end
# make sure the port number below reflects the one from your openvpn server
echo "Allowing openvpn traffic"
iptables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT

# allow dns because it's a third party system app that tries to do it (and not openvpn)
echo "Allowing DNS for resolving openvpn server"
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# allow traffic on tun0 and lo
echo "Allowing lo and tun interfaces" 
iptables -A OUTPUT -j ACCEPT -o lo 
iptables -A OUTPUT -j ACCEPT -o tun+

# allow forward traffic only from tun0
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# this is important we need to send all traffic that is being forwarded to tun0
iptables -A FORWARD -i $IFACE -o tun0 -j ACCEPT 

# masq traffic on tun0
echo "Masquerading traffic on tun0"
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# this is the path of your VPN configuration
openvpn PATH_TO_YOUR_VPN_FILE.ovpn &

echo "Waiting for VPN to initialize"
sleep 10 

echo "Current IP: `curl -s ifconfig.co`"

echo "Setting policy in output and input chain to drop"
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

# block dns because it's a third party system app that tries to do it (and not openvpn)
echo "Blocking DNS for resolving openvpn server"
iptables -D OUTPUT -p udp --dport 53 -j ACCEPT

echo "Turning on IP forwarding"
sysctl -w net.ipv4.ip_forward=1
