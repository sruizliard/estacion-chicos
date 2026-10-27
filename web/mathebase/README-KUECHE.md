NOTA (Claude, estacion-chicos): en este Chromebook NO hace falta nada de lo de abajo.
  - Actualizar:  sudo estacion-update   (el servidor server/server.py arranca solo con el sistema)
  - Nombres, PIN y webhook de la cocina:  sudo estacion-config   (se guardan en /etc/estacion, fuera de Git)

# MatheBase → Küchen-Bildschirm (TRMNL)

Kette: Runde ≥4/5 richtig → 1×/Tag «Lesen oder Üben» → `POST /api/mathe/kueche` an `server.py` (localhost:8765)
→ Webhook der Automation **mathebase-cocina** → `mathe_streak.py add <kind> <date> --tick` + TRMNL-Push.

## Damit es funktioniert (alle 3 nötig)
1. App über **http://localhost:8765/** öffnen (nicht als Datei, nicht `python3 -m http.server`), gestartet mit `python3 server.py`.
2. Papa-Menü → jedes Profil → **Küchen-Kind** wählen → *Profil speichern*. Ohne das wird nichts gesendet (rote Warnung).
3. Datei `~/.config/estacion/webhook.env` auf der Chromebook (Linux), NICHT ins Git:
   ```
   MATHEBASE_WEBHOOK_URL=<Webhook-URL der Automation mathebase-cocina>
   MATHEBASE_WEBHOOK_KEY=<Sender-Key derselben Automation>
   ```
   URL und Key: Grok Bot → Seitenleiste → Automations/Routinen → **mathebase-cocina** → Trigger „Webhook“ → URL + Key kopieren.
   `chmod 600 ~/.config/estacion/webhook.env`, danach `server.py` neu starten.

## Testen
- Papa-Menü → **Test Küche (Ping)**: sendet `{"action":"ping"}`, setzt KEIN Häkchen. ✅ = Webhook erreichbar; ❌ zeigt den Grund.
- Terminal: `curl -s -XPOST localhost:8765/api/mathe/kueche -d '{"action":"ping"}'`
  → `"forwarded": true` ok · `no_webhook_config` = webhook.env fehlt · `forward_failed` = URL/Key/Internet.
- Log der Versuche: `~/.local/share/estacion/mathe-inbox.jsonl`.
- Ausstehende Punkte (nicht weitergeleitet) bleiben jetzt offen → Papa-Menü → *Ausstehende Küchenpunkte senden*.
