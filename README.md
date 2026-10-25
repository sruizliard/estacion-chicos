# Estación de deberes

Configuración del Samsung Chromebook XE303C12 (Debian 13, velvet-os) como estación de deberes para niños.

## Instalar (en el Chromebook, con el usuario administrador)

```
sudo apt install -y git
git clone https://github.com/sruizliard/estacion-chicos
sudo bash estacion-chicos/setup.sh
```

## Actualizar (después de cambios en este repo)

```
sudo estacion-update
```

## Inicio automático con el usuario de los chicos

```
sudo bash /opt/estacion/repo/autologin.sh on    # activar
sudo bash /opt/estacion/repo/autologin.sh off   # desactivar
```

## Qué hace `setup.sh`

- Instala GCompris, Tux Paint y Thonny
- Página de inicio local "Lernen" en `http://127.0.0.1:8765` (carpeta `web/`)
- MatheBase va en `web/mathebase/` (HTML/CSS/JS estático, sin framework)
- Firefox con lista blanca: solo la página local, Klexikon, ANTON, Antolin y sofatutor (`config/firefox-policies.json`)
- Iconos en el escritorio del usuario `chicos` y sin bloqueo de pantalla
- Comando `estacion-update` para aplicar cambios del repo

## Añadir una web a la lista blanca

Editar `config/firefox-policies.json` → `Exceptions`, hacer push y ejecutar `sudo estacion-update` en el Chromebook.
