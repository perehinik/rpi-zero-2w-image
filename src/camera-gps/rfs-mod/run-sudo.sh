#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

# set default shell to bash
echo "DSHELL=/bin/bash" >> /etc/adduser.conf

print_step "Create pi user"
# Create pi user if it doesn't already exist
if ! id pi >/dev/null 2>&1; then
    useradd -m -s /bin/bash pi
fi

echo "Set password pi for user pi"
echo "pi:pi" | /sbin/chpasswd

echo "Add pi to sudo group"
usermod -aG sudo pi

# Install additional packages
apt-get update
apt-get install -y vim htop curl

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

apt-get install -y net-tools ifupdown iputils-ping

apt-get install -y wpasupplicant wireless-regdb iw

# Add rpi lists
curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | gpg --dearmor -o /usr/share/keyrings/rpi-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/rpi-archive-keyring.gpg] http://archive.raspberrypi.org/debian bookworm main" >> /etc/apt/sources.list.d/raspi.list

# Camera, GPS
apt-get update
apt-get install -y rpicam-apps-lite python3 python3-serial sudo

# Cleanup
apt-get remove -y avahi-daemon
apt-get remove -y nano
apt-get autoremove -y
apt-get clean
