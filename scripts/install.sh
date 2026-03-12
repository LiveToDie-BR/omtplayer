#!/usr/bin/env bash
set -e

REPO_URL="${REPO_URL:-https://github.com/LiveToDie-BR/omtplayer.git}"
INSTALL_DIR="/opt/omtplayer"
BIN_LINK="/usr/local/bin/omtplayer"
SETUP_LINK="/usr/local/bin/omtplayer-setup"

echo "[1/8] Instalando dependencias..."
sudo apt update
sudo apt install -y git clang libsdl2-2.0-0 libsdl2-dev avahi-daemon avahi-utils alsa-utils

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "[2/8] Baixando repositorio..."
git clone "$REPO_URL" "$WORKDIR/omtplayer"

cd "$WORKDIR/omtplayer"

echo "[3/8] Compilando..."
bash scripts/build.sh

echo "[4/8] Instalando arquivos..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp build/omtplayer "$INSTALL_DIR/"
sudo cp lib/libomt.so "$INSTALL_DIR/"
sudo cp lib/libvmx.so "$INSTALL_DIR/"
sudo cp scripts/run.sh "$INSTALL_DIR/"
sudo cp scripts/setup.sh "$INSTALL_DIR/"

echo "[5/8] Ajustando permissoes..."
sudo chmod +x "$INSTALL_DIR/run.sh"
sudo chmod +x "$INSTALL_DIR/setup.sh"

echo "[6/8] Criando comandos globais..."
sudo ln -sf "$INSTALL_DIR/omtplayer" "$BIN_LINK"
sudo ln -sf "$INSTALL_DIR/setup.sh" "$SETUP_LINK"

echo "[7/8] Instalando servico systemd..."
sudo cp systemd/omtplayer.service /etc/systemd/system/omtplayer.service
sudo systemctl daemon-reload

echo "[8/8] Instalacao concluida."
echo
echo "Agora execute:"
echo "  sudo omtplayer-setup"
echo
echo "Depois voce podera controlar com:"
echo "  sudo systemctl start omtplayer.service"
echo "  sudo systemctl stop omtplayer.service"
echo "  systemctl status omtplayer.service"
