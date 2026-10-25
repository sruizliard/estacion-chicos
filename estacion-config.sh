#!/bin/bash
# Configura nombres de los niños, PIN de Papa/Mama y (opcional) el webhook de la cocina.
# Todo se guarda SOLO en este Chromebook (/etc/estacion), nunca en GitHub.
# Uso:  sudo estacion-config

set -e
DIR="/etc/estacion"
CFG="$DIR/mathebase.json"
HOOK="$DIR/webhook.env"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecútalo con sudo:  sudo estacion-config"
  exit 1
fi
mkdir -p "$DIR"

ask() {   # $1 = pregunta, $2 = valor por defecto
  local v
  read -r -p "$1 [${2}]: " v
  echo "${v:-$2}"
}

echo
echo "== MatheBase: niños y PIN =="
echo "(Enter = dejar el valor entre corchetes)"
echo

N1=$(ask "Niño 1 – nombre que se ve" "Kind 1")
I1=$(ask "Niño 1 – ID de la cocina (minúsculas, sin espacios)" "kind1")
N2=$(ask "Niño 2 – nombre que se ve" "Kind 2")
I2=$(ask "Niño 2 – ID de la cocina (minúsculas, sin espacios)" "kind2")

while true; do
  read -r -s -p "PIN de Papa/Mama (4 cifras): " PIN; echo
  [[ "$PIN" =~ ^[0-9]{4}$ ]] && break
  echo "  Tienen que ser exactamente 4 cifras."
done

python3 - "$CFG" "$PIN" "$N1" "$I1" "$N2" "$I2" <<'PY'
import json, sys
path, pin, n1, i1, n2, i2 = sys.argv[1:]
cfg = {"pin": pin, "kinder": [{"id": i1, "name": n1}, {"id": i2, "name": n2}]}
open(path, "w", encoding="utf-8").write(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")
PY
chown root:nogroup "$CFG"
chmod 640 "$CFG"
echo "✔ Guardado en $CFG"

echo
read -r -p "¿Configurar ahora el webhook de la cocina? (s/N): " W
if [[ "$W" =~ ^[sSyY] ]]; then
  read -r -p "MATHEBASE_WEBHOOK_URL: " URL
  read -r -s -p "MATHEBASE_WEBHOOK_KEY: " KEY; echo
  printf 'MATHEBASE_WEBHOOK_URL=%s\nMATHEBASE_WEBHOOK_KEY=%s\n' "$URL" "$KEY" > "$HOOK"
  chown root:nogroup "$HOOK"
  chmod 640 "$HOOK"
  echo "✔ Webhook guardado en $HOOK"
else
  echo "• Webhook sin cambios (sin webhook: solo se guarda un registro local)."
fi

systemctl restart estacion-web.service
echo
echo "✔ Listo. Recarga MatheBase en Firefox (F5)."
