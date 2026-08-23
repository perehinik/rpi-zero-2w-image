#!/bin/sh
set -e

sudo cp ./gps_logger.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/gps_logger.service

sudo cp ./gps_logger.sh /usr/sbin

sudo systemctl daemon-reload
sudo systemctl enable gps_logger.service
