#!/bin/bash
# Inicio automático con el usuario de los chicos
# Uso:  sudo bash autologin.sh on    (activar)
#       sudo bash autologin.sh off   (desactivar)

KIDUSER="chicos"
CONF="/etc/lightdm/lightdm.conf.d/50-estacion-autologin.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecútalo con sudo:  sudo bash $0 on|off"
  exit 1
fi

case "$1" in
  on)
    mkdir -p /etc/lightdm/lightdm.conf.d
    printf '[Seat:*]\nautologin-user=%s\nautologin-user-timeout=0\n' "$KIDUSER" > "$CONF"
    echo "✔ Inicio automático ACTIVADO para '$KIDUSER' (se aplica al reiniciar)."
    ;;
  off)
    rm -f "$CONF"
    echo "✔ Inicio automático DESACTIVADO (se aplica al reiniciar)."
    ;;
  *)
    echo "Uso: sudo bash $0 on|off"
    exit 1
    ;;
esac
