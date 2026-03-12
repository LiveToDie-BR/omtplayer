#!/usr/bin/env bash
set -e

CONFIG_FILE="/etc/omtplayer.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo omtplayer-setup"
  exit 1
fi

echo "========================================"
echo " OMT Player Setup"
echo "========================================"
echo

echo "[1/5] Procurando sources OMT na rede..."
mapfile -t SOURCES < <(
  avahi-browse -rt _omt._tcp 2>/dev/null \
    | awk '
      /^=/ {
        line=$0
        sub(/^= +[^ ]+ +[^ ]+ +/, "", line)
        sub(/ +_omt\._tcp.*$/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        if (line != "") print line
      }' \
    | sort -u
)

if [ "${#SOURCES[@]}" -eq 0 ]; then
  echo "Nenhum source OMT encontrado."
  echo "Verifique se o sender esta ligado e se o avahi-daemon esta rodando."
  exit 1
fi

echo
echo "Sources OMT encontrados:"
for i in "${!SOURCES[@]}"; do
  n=$((i+1))
  echo "  $n) ${SOURCES[$i]}"
done

echo
read -rp "Escolha o numero do source: " SOURCE_INDEX

if ! [[ "$SOURCE_INDEX" =~ ^[0-9]+$ ]] || [ "$SOURCE_INDEX" -lt 1 ] || [ "$SOURCE_INDEX" -gt "${#SOURCES[@]}" ]; then
  echo "Opcao invalida."
  exit 1
fi

SOURCE_LINE="${SOURCES[$((SOURCE_INDEX-1))]}"
SOURCE="$(printf '%s\n' "$SOURCE_LINE" | cut -d'|' -f1 | sed 's/[[:space:]]*$//')"

echo
echo "[2/5] Listando dispositivos de audio..."
mapfile -t AUDIO_LINES < <(
  aplay -l 2>/dev/null | awk '
    /^card [0-9]+:/ {
      line=$0
      card=$2
      gsub(":", "", card)
      for (i=1; i<=NF; i++) {
        if ($i=="device") {
          dev=$(i+1)
          gsub(":", "", dev)
          print "hw:" card "," dev " | " line
        }
      }
    }'
)

if [ "${#AUDIO_LINES[@]}" -eq 0 ]; then
  echo "Nenhum dispositivo de audio encontrado."
  exit 1
fi

echo
echo "Dispositivos de audio:"
for i in "${!AUDIO_LINES[@]}"; do
  n=$((i+1))
  line="${AUDIO_LINES[$i]}"
  if printf '%s' "$line" | grep -qi 'HDMI'; then
    echo "  $n) $line   [recomendado para TV/monitor HDMI]"
  else
    echo "  $n) $line"
  fi
done

DEFAULT_AUDIO_INDEX=""
for i in "${!AUDIO_LINES[@]}"; do
  if printf '%s' "${AUDIO_LINES[$i]}" | grep -qi 'HDMI'; then
    DEFAULT_AUDIO_INDEX=$((i+1))
    break
  fi
done

echo
if [ -n "$DEFAULT_AUDIO_INDEX" ]; then
  echo "Dica: normalmente a melhor opcao e o primeiro dispositivo HDMI."
  echo "Se nao houver som, rode novamente o setup e teste outra interface."
  read -rp "Escolha o numero do dispositivo de audio [${DEFAULT_AUDIO_INDEX}]: " AUDIO_INDEX
  AUDIO_INDEX="${AUDIO_INDEX:-$DEFAULT_AUDIO_INDEX}"
else
  read -rp "Escolha o numero do dispositivo de audio: " AUDIO_INDEX
fi

if ! [[ "$AUDIO_INDEX" =~ ^[0-9]+$ ]] || [ "$AUDIO_INDEX" -lt 1 ] || [ "$AUDIO_INDEX" -gt "${#AUDIO_LINES[@]}" ]; then
  echo "Opcao invalida."
  exit 1
fi

AUDIO_LINE="${AUDIO_LINES[$((AUDIO_INDEX-1))]}"
AUDIODEV="$(printf '%s\n' "$AUDIO_LINE" | cut -d'|' -f1 | xargs)"

echo
echo "Display de video:"
echo "  Normalmente use :0"
echo "  Esse valor define em qual sessao grafica local o video vai abrir."
echo "  Em quase todos os casos de TV/monitor conectado ao PC, o correto e :0"
read -rp "Display de video [:0]: " DISPLAY_VALUE
DISPLAY_VALUE="${DISPLAY_VALUE:-:0}"

echo
echo "[3/5] Gravando configuracao em $CONFIG_FILE ..."
cat > "$CONFIG_FILE" <<EOF
SOURCE="$SOURCE"
AUDIODEV="$AUDIODEV"
DISPLAY="$DISPLAY_VALUE"
SDL_AUDIODRIVER="alsa"
EOF

chmod 644 "$CONFIG_FILE"

echo
echo "Configuracao gravada:"
cat "$CONFIG_FILE"

echo
read -rp "[4/5] Deseja habilitar inicio automatico no boot? [s/N]: " ENABLE_BOOT
if [[ "$ENABLE_BOOT" =~ ^[sS]$ ]]; then
  systemctl enable omtplayer.service
  echo "Auto start habilitado."
else
  systemctl disable omtplayer.service >/dev/null 2>&1 || true
  echo "Auto start desabilitado."
fi

echo
read -rp "[5/5] Deseja iniciar o player agora? [s/N]: " START_NOW
if [[ "$START_NOW" =~ ^[sS]$ ]]; then
  systemctl restart omtplayer.service
  echo "Player iniciado."
  echo "Use: systemctl status omtplayer.service"
else
  systemctl stop omtplayer.service >/dev/null 2>&1 || true
  echo "Player nao iniciado."
  echo
  echo "Para iniciar manualmente depois, use:"
  echo "  sudo systemctl start omtplayer.service"
fi

echo
echo "======================================"
echo "Configuracao concluida."
echo
echo "Comandos uteis:"
echo "  sudo systemctl start omtplayer.service"
echo "  sudo systemctl stop omtplayer.service"
echo "  sudo systemctl restart omtplayer.service"
echo "  systemctl status omtplayer.service"
echo "  journalctl -u omtplayer.service -f"
echo
echo "Para alterar a configuracao depois:"
echo "  sudo omtplayer-setup"
echo "======================================"
