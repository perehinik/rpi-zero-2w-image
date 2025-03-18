#!/bin/bash

echo; echo "--- CUSTOM STEPS FOR RPI ZERO 2W ---"; echo;

echo "Set password root for user root"
echo "root:root" | /sbin/chpasswd

# Install additional packages
apt-get update
apt-get install -y vim htop

# Create swap file
fallocate -l 2G /swapfile
dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
# swapfile should be also added to fstab
# /dev/sdXn none swap sw 0 0
