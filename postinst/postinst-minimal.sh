#!/bin/bash

echo; echo "--- CUSTOM STEPS FOR RPI ZERO 2W ---"; echo;

echo "Set password root for user root"
echo "root:root" | /sbin/chpasswd

# Install additional packages
apt-get update
apt-get install -y vim htop

# Install systemd
apt-get install -y systemd systemd-sysv

# Create swap file
fallocate -l 1G /swapfile
dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
# swapfile should be also added to fstab
# /dev/sdXn none swap sw 0 0

# Packages for proper mount of /boot using /etc/fstab
apt-get install -y kmod dosfstools udisks2

# Cleanup
apt-get remove -y avahi-daemon
apt-get remove -y nano
apt-get autoremove -y
apt-get clean
