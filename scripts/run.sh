#!/usr/bin/env bash
set -e

CONFIG_FILE="/etc/omtplayer.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Arquivo $CONFIG_FILE nao encontrado."
  echo "Execute: sudo omtplayer-setup"
  exit 1
fi

# shellcheck disable=SC1091
source "$CONFIG_FILE"

if [ -z "${SOURCE:-}" ]; then
  echo "SOURCE nao definido em $CONFIG_FILE"
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
export AUDIODEV="${AUDIODEV:-hw:0,3}"

exec /opt/omtplayer/omtplayer "$SOURCE"
