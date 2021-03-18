#!/bin/bash

# Creates an access point and routes traffic to LAN
#
# Make sure you have already installed
#           dnsmasq
#           hostapd
#
# Please modify the variables according to your need

ip_address="192.168.2.1"
netmask="255.255.255.0"
dhcp_range_start="192.168.2.2"
dhcp_range_end="192.168.2.100"
dhcp_time="12h"
wlan0="eth0"
wlan1="wlan0" # RPi wifi is wlan0
ssid="Raspberry-Hotspot"
psk="raspberry"

sudo kill -9 $(ps aux | grep "$wlan1" | grep -v 'grep' | awk '{print $2}') &> /dev/null

sudo rfkill unblock wifi &> /dev/null
#sudo rfkill unblock wlan1 &> /dev/null
sleep 2

sudo systemctl start network-online.target

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -o $wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i $wlan0 -o $wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $wlan1 -o $wlan0 -j ACCEPT

sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Remove default route
sudo ip route del 0/0 dev $wlan1 &> /dev/null

sudo ifconfig $wlan1 $ip_address netmask $netmask

sudo rm -rf /etc/dnsmasq.d/* &> /dev/null

sudo echo -e "interface=$wlan1 \n\
bind-interfaces \n\
server=8.8.8.8 \n\
domain-needed \n\
bogus-priv \n\
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /etc/dnsmasq.d/custom-dnsmasq.conf

sudo systemctl restart dnsmasq

echo -e "interface=$wlan1\n\
driver=nl80211\n\
ssid=$ssid\n\
hw_mode=g\n\
ieee80211n=1\n\
wmm_enabled=1\n\
macaddr_acl=0\n\
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]\n\
channel=6\n\
auth_algs=1\n\
ignore_broadcast_ssid=0\n\
wpa=2\n\
wpa_key_mgmt=WPA-PSK\n\
wpa_passphrase=$psk\n\
rsn_pairwise=CCMP" > /tmp/hostapd.conf

sudo systemctl stop hostapd
sudo hostapd /tmp/hostapd.conf &
