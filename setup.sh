#!/bin/bash
# Estación de deberes – configuración completa del Chromebook (Debian 13)
# Uso:  sudo bash setup.sh
# Se puede ejecutar todas las veces que haga falta: solo actualiza lo necesario.

set -e

KIDUSER="chicos"
BASE="/opt/estacion"
REPO="$BASE/repo"
WEB="$BASE/web"
PORT="8765"

ok()   { echo -e "\e[32m✔\e[0m $1"; }
info() { echo -e "\n\e[1m▶ $1\e[0m"; }
warn() { echo -e "\e[33m!\e[0m $1"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecútalo con sudo:  sudo bash $0"
  exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------- 0. Repo en /opt
info "Copiando la configuración a $REPO"
mkdir -p "$BASE"
if [ "$SRC" != "$REPO" ]; then
  rm -rf "$REPO"
  cp -a "$SRC" "$REPO"
fi
ok "Repositorio en $REPO"

# ---------------------------------------------------------------- 1. Usuario
info "Usuario de los chicos"
if id "$KIDUSER" >/dev/null 2>&1; then
  ok "El usuario '$KIDUSER' ya existe"
else
  adduser --disabled-password --gecos "" "$KIDUSER"
  warn "Usuario '$KIDUSER' creado SIN contraseña. Ponle una con:  sudo passwd $KIDUSER"
fi
KIDHOME="$(getent passwd "$KIDUSER" | cut -d: -f6)"

# ---------------------------------------------------------------- 2. Programas
info "Instalando programas (puede tardar 10–20 min la primera vez)"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  gcompris-qt tuxpaint thonny python3 git fonts-noto-color-emoji >/dev/null
ok "GCompris, Tux Paint, Thonny"

# ---------------------------------------------------------------- 3. Página de inicio local
info "Página de inicio y MatheBase (servidor local en 127.0.0.1:$PORT)"
rm -rf "$WEB"
cp -a "$REPO/web" "$WEB"
chmod -R a+rX "$WEB"

cat > /etc/systemd/system/estacion-web.service <<EOF
[Unit]
Description=Estacion de deberes - servidor web local
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server $PORT --bind 127.0.0.1 --directory $WEB
User=nobody
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now estacion-web.service >/dev/null 2>&1
systemctl restart estacion-web.service
ok "Servidor activo: http://127.0.0.1:$PORT"

# ---------------------------------------------------------------- 4. Firefox con lista blanca
info "Firefox: solo webs permitidas"
mkdir -p /etc/firefox/policies /usr/lib/firefox-esr/distribution
cp "$REPO/config/firefox-policies.json" /etc/firefox/policies/policies.json
cp "$REPO/config/firefox-policies.json" /usr/lib/firefox-esr/distribution/policies.json
ok "Lista blanca aplicada (revísala en Firefox con about:policies)"

# ---------------------------------------------------------------- 5. Escritorio de los chicos
info "Escritorio de los chicos"
DESK="$KIDHOME/Desktop"
mkdir -p "$DESK"

add_launcher() {   # $1 = patrón del .desktop del programa
  local f
  f="$(ls /usr/share/applications/ 2>/dev/null | grep -i "$1" | grep -v -i config | grep '\.desktop$' | head -n1)"
  if [ -n "$f" ]; then
    cp "/usr/share/applications/$f" "$DESK/"
    ok "Icono: $f"
  else
    warn "No encontré el icono de $1"
  fi
}
add_launcher gcompris
add_launcher tuxpaint
add_launcher thonny

cat > "$DESK/lernen.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Lernen
Comment=MatheBase, Klexikon, ANTON, Antolin, sofatutor
Exec=firefox-esr http://127.0.0.1:$PORT/
Icon=firefox-esr
Terminal=false
EOF
ok "Icono: Lernen (página de inicio)"

rm -f "$DESK"/*config*.desktop
chmod +x "$DESK"/*.desktop

# Sin bloqueo de pantalla para los chicos (la pantalla sí se apaga para ahorrar)
XFCONF="$KIDHOME/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCONF"
cat > "$XFCONF/xfce4-screensaver.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF
mkdir -p "$KIDHOME/.config/autostart"
printf '[Desktop Entry]\nHidden=true\n' > "$KIDHOME/.config/autostart/light-locker.desktop"

chown -R "$KIDUSER:$KIDUSER" "$KIDHOME/Desktop" "$KIDHOME/.config"
ok "Bloqueo de pantalla desactivado para '$KIDUSER'"

# ---------------------------------------------------------------- 6. Comando de actualización
cat > /usr/local/bin/estacion-update <<EOF
#!/bin/bash
set -e
cd $REPO
git pull --ff-only
bash $REPO/setup.sh
EOF
chmod +x /usr/local/bin/estacion-update
ok "Para actualizar en el futuro:  sudo estacion-update"

echo
echo -e "\e[32m\e[1m✔ Listo.\e[0m"
echo "  • Cierra sesión y entra como '$KIDUSER' para verlo."
echo "  • Inicio automático (al final):  sudo bash $REPO/autologin.sh on"
