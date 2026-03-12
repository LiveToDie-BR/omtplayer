#!/usr/bin/env bash
set -e

sudo systemctl disable --now omtplayer.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/omtplayer.service
sudo systemctl daemon-reload

sudo rm -f /usr/local/bin/omtplayer
sudo rm -rf /opt/omtplayer

echo "omtplayer removido."
