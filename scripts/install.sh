#!/usr/bin/env bash
set -e

REPO_URL="${REPO_URL:-https://github.com/LiveToDie-BR/omtplayer.git}"
INSTALL_DIR="/opt/omtplayer"
BIN_LINK="/usr/local/bin/omtplayer"

echo "[1/6] Instalando dependencias..."
sudo apt update
sudo apt install -y git clang libsdl2-2.0-0 libsdl2-dev avahi-daemon avahi-utils

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "[2/6] Baixando repositorio..."
git clone "$REPO_URL" "$WORKDIR/omtplayer"

cd "$WORKDIR/omtplayer"

echo "[3/6] Compilando..."
bash scripts/build.sh

echo "[4/6] Instalando arquivos..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp build/omtplayer "$INSTALL_DIR/"
sudo cp lib/libomt.so "$INSTALL_DIR/"
sudo cp lib/libvmx.so "$INSTALL_DIR/"

echo "[5/6] Criando comando global..."
sudo ln -sf "$INSTALL_DIR/omtplayer" "$BIN_LINK"

echo "[6/6] Instalacao concluida."
echo
echo "Teste manual:"
echo 'DISPLAY=:0 SDL_AUDIODRIVER=alsa AUDIODEV=hw:0,3 omtplayer "NOME_DO_SOURCE"'
