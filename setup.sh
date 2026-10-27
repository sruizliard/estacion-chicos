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

# Programas extra: se instalan uno a uno; si alguno no existe en Debian, se salta
EXTRA_PKGS="firefox-esr-l10n-de locales \
  tuxmath tuxtype klettres ktouch kbruch kgeography \
  kturtle gbrainy kig eduactiv8 pysiogame gtans xaos khangman kanagram kwordquiz marble \
  pencil2d mypaint hydrogen pianobooster \
  pingus numptyphysics frozen-bubble hex-a-hop lbreakout2 ri-li gnome-chess 2048-qt"
for pkg in $EXTRA_PKGS; do
  if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
    ok "$pkg"
  else
    warn "$pkg no disponible en esta versión de Debian (se omite)"
  fi
done

# Snap! (programación con bloques, tipo Scratch) servido en local, sin internet
SNAP_VER="v12.3.7"
SNAP_DIR="$BASE/snap"
if [ "$(cat "$SNAP_DIR/.version" 2>/dev/null)" != "$SNAP_VER" ]; then
  info "Descargando Snap! $SNAP_VER (unos 180 MB, solo la primera vez)"
  rm -rf "$SNAP_DIR.tmp"
  if git clone -q --depth 1 --branch "$SNAP_VER" https://github.com/jmoenig/Snap "$SNAP_DIR.tmp"; then
    rm -rf "$SNAP_DIR.tmp/.git" "$SNAP_DIR"
    mv "$SNAP_DIR.tmp" "$SNAP_DIR"
    echo "$SNAP_VER" > "$SNAP_DIR/.version"
    chmod -R a+rX "$SNAP_DIR"
    ok "Snap! $SNAP_VER"
  else
    rm -rf "$SNAP_DIR.tmp"
    warn "No se pudo descargar Snap! (¿hay internet?). Se reintentará en el próximo estacion-update"
  fi
else
  ok "Snap! $SNAP_VER"
fi

# ---------------------------------------------------------------- 3. Página de inicio local
info "Página de inicio y MatheBase (servidor local en 127.0.0.1:$PORT)"
rm -rf "$WEB"
cp -a "$REPO/web" "$WEB"
[ -d "$BASE/snap" ] && ln -sfn "$BASE/snap" "$WEB/snap"
chmod -R a+rX "$WEB"

cat > /etc/systemd/system/estacion-web.service <<EOF
[Unit]
Description=Estacion de deberes - servidor web local
After=network.target

[Service]
ExecStart=/usr/bin/python3 $REPO/server/server.py
Environment=ESTACION_PORT=$PORT
Environment=ESTACION_ROOT=$WEB
Environment=ESTACION_CONFIG=/etc/estacion
Environment=ESTACION_STATE=/var/lib/estacion
StateDirectory=estacion
User=nobody
Group=nogroup
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now estacion-web.service >/dev/null 2>&1
systemctl restart estacion-web.service
ok "Servidor activo: http://127.0.0.1:$PORT"

mkdir -p /etc/estacion
install -m 755 "$REPO/estacion-config.sh" /usr/local/bin/estacion-config
if [ ! -f /etc/estacion/mathebase.json ]; then
  warn "MatheBase aún sin nombres ni PIN. Configúralo con:  sudo estacion-config"
else
  ok "MatheBase configurado (nombres y PIN en /etc/estacion, fuera de GitHub)"
fi

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

# Iconos ordenados en carpetas; se regeneran en cada update
rm -f "$DESK"/*.desktop
for d in "Lernen & Üben" "Malen & Musik" "Spiele" "Programmieren"; do
  rm -rf "$DESK/$d"; mkdir -p "$DESK/$d"
done

add_launcher() {   # $1 = carpeta, $2 = patrón del .desktop del programa
  local f
  for f in $(ls /usr/share/applications/ 2>/dev/null | grep -i "$2" | grep -v -i config | grep '\.desktop$'); do
    grep -qi '^NoDisplay=true' "/usr/share/applications/$f" && continue
    cp "/usr/share/applications/$f" "$DESK/$1/"
    return 0
  done
  return 1
}

N=0
for spec in \
  "Lernen & Üben:gcompris" "Lernen & Üben:tuxmath" "Lernen & Üben:tuxtype" "Lernen & Üben:ktouch" \
  "Lernen & Üben:klettres" "Lernen & Üben:kbruch" "Lernen & Üben:kgeography" "Lernen & Üben:gbrainy" \
  "Lernen & Üben:kig" "Lernen & Üben:eduactiv8" "Lernen & Üben:pysiogame" "Lernen & Üben:gtans" \
  "Lernen & Üben:xaos" "Lernen & Üben:khangman" "Lernen & Üben:kanagram" "Lernen & Üben:kwordquiz" \
  "Lernen & Üben:marble" \
  "Malen & Musik:tuxpaint" "Malen & Musik:pencil2d" "Malen & Musik:mypaint" "Malen & Musik:hydrogen" \
  "Malen & Musik:pianobooster" \
  "Spiele:pingus" "Spiele:numptyphysics" "Spiele:frozen-bubble" "Spiele:hex-a-hop" "Spiele:lbreakout2" \
  "Spiele:ri-li" "Spiele:chess" "Spiele:2048" \
  "Programmieren:thonny" "Programmieren:kturtle"; do
  add_launcher "${spec%%:*}" "${spec#*:}" && N=$((N+1))
done
ok "$N programas en las carpetas del escritorio"

cat > "$DESK/lernen.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Lernen
Comment=MatheBase, Snap!, Klexikon, ANTON, Antolin und mehr
Exec=firefox-esr http://127.0.0.1:$PORT/
Icon=firefox-esr
Terminal=false
EOF
ok "Icono: Lernen (página de inicio)"

find "$DESK" -name '*.desktop' -exec chmod +x {} +

# Marcar los iconos como seguros al entrar (sin la pregunta "Untrusted launcher")
cat > /usr/local/bin/estacion-trust-launchers <<'EOF'
#!/bin/bash
find "$HOME/Desktop" -name '*.desktop' | while read -r f; do
  gio set -t string "$f" metadata::xfce-exe-checksum "$(sha256sum "$f" | cut -d' ' -f1)" 2>/dev/null
done
EOF
chmod +x /usr/local/bin/estacion-trust-launchers
mkdir -p "$KIDHOME/.config/autostart"
printf '[Desktop Entry]\nType=Application\nName=Estacion Launcher\nExec=/usr/local/bin/estacion-trust-launchers\nNoDisplay=true\n' \
  > "$KIDHOME/.config/autostart/estacion-trust.desktop"

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

# Teclado alemán (ä ö ü ß) solo para los chicos; el admin sigue con el americano
cat > "$XFCONF/keyboard-layout.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="keyboard-layout" version="1.0">
  <property name="Default" type="empty">
    <property name="XkbDisable" type="bool" value="false"/>
    <property name="XkbLayout" type="string" value="de"/>
    <property name="XkbVariant" type="string" value="nodeadkeys"/>
  </property>
</channel>
EOF

# Todo en alemán para los chicos (el admin sigue en inglés)
touch /etc/locale.gen
sed -i 's/^# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^de_DE.UTF-8 UTF-8' /etc/locale.gen || echo 'de_DE.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen >/dev/null 2>&1 || localedef -i de_DE -f UTF-8 de_DE.UTF-8 >/dev/null 2>&1 || true
if locale -a 2>/dev/null | grep -qi '^de_DE\.utf-\?8$'; then
  ok "Idioma alemán (de_DE.UTF-8) disponible"
else
  warn "No se pudo generar el idioma alemán (de_DE.UTF-8)"
fi
# El idioma se fija por tres vías, porque cada parte del arranque lee una distinta
LANGLINES='export LANG=de_DE.UTF-8\nexport LANGUAGE=de_DE:de\nexport LC_ALL=de_DE.UTF-8\n'
printf "$LANGLINES" > "$KIDHOME/.xsessionrc"
printf "$LANGLINES" > "$KIDHOME/.xprofile"
printf '[Desktop]\nLanguage=de_DE.UTF-8\n' > "$KIDHOME/.dmrc"
chmod 644 "$KIDHOME/.dmrc"
chown "$KIDUSER:$KIDUSER" "$KIDHOME/.xsessionrc" "$KIDHOME/.xprofile" "$KIDHOME/.dmrc"
AS="/var/lib/AccountsService/users/$KIDUSER"
if [ -d /var/lib/AccountsService/users ]; then
  if [ -f "$AS" ] && grep -q '^Language=' "$AS"; then
    sed -i 's/^Language=.*/Language=de_DE.UTF-8/' "$AS"
  elif [ -f "$AS" ]; then
    sed -i '/^\[User\]/a Language=de_DE.UTF-8' "$AS"
  else
    printf '[User]\nLanguage=de_DE.UTF-8\n' > "$AS"
  fi
fi

chown -R "$KIDUSER:$KIDUSER" "$KIDHOME/Desktop" "$KIDHOME/.config"
ok "Bloqueo de pantalla desactivado para '$KIDUSER'"
ok "Teclado alemán para '$KIDUSER' (se aplica al volver a entrar)"
ok "Idioma alemán para '$KIDUSER' (se aplica al volver a entrar)"

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
