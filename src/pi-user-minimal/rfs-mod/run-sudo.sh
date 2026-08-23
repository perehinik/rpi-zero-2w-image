#!/bin/sh
set -e

USER_NAME="pi"
USER_PSWD="pi"

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

# set default shell to bash
echo "DSHELL=/bin/bash" >> /etc/adduser.conf

print_step "Create ${USER_NAME} user"
# Create user if it doesn't already exist
if ! id ${USER_NAME} >/dev/null 2>&1; then
    useradd -m -s /bin/bash ${USER_NAME}
fi

echo "Set password ${USER_PSWD} for user ${USER_NAME}"
echo "${USER_NAME}:${USER_PSWD}" | /sbin/chpasswd

echo "Add ${USER_NAME} to sudo group"
usermod -aG sudo ${USER_NAME}
usermod -aG dialout ${USER_NAME}

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

# Remote control
apt-get install -y avahi-daemon

# Cleanup
apt-get remove -y nano
apt-get autoremove -y
apt-get clean
