# OMT Player for Debian

Player simples para receber OMT e exibir em HDMI no Debian/Linux.

## Instalação rápida

```bash
curl -fsSL https://raw.githubusercontent.com/LiveToDie-BR/omtplayer/main/scripts/install.sh | bash

EXECUÇÃO MANUAL
DISPLAY=:0 SDL_AUDIODRIVER=alsa AUDIODEV=hw:0,3 omtplayer "NOTE-LUCIANO (vMix - Output 1)"
