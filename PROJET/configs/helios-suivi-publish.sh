#!/bin/bash
# helios-suivi-publish.sh - publie etat.json a partir de la derniere ligne de telemetry.csv
# rc : 0 ok | 1 erreur interne (ligne invalide) | 2 deja en cours | 3 prerequis manquant
set -Eeuo pipefail

TAG=helios-suivi-publish
SRC=/var/lib/helios/telemetry.csv
WWW=/srv/helios/suivi/www
DEST=$WWW/etat.json
TMP=""

log() { logger -t "$TAG" -- "$*"; }
cleanup() { if [ -n "$TMP" ]; then rm -f "$TMP"; fi; }
trap cleanup EXIT
trap 'log "erreur ligne $LINENO"; exit 1' ERR

# verrou sur le script lui-meme (lecture seule : pas besoin d'ecrire, ok avec ProtectSystem=strict)
exec 9<"$0"
if ! flock -n 9; then log "une autre instance tourne deja"; exit 2; fi

if [ ! -r "$SRC" ]; then log "telemetrie illisible : $SRC"; exit 3; fi
if [ ! -w "$WWW" ]; then log "$WWW non inscriptible pour $(id -un)"; exit 3; fi

LIGNE=$(tail -n 1 "$SRC")
if ! [[ $LIGNE =~ ^([0-9T:+-]+),([0-9.]+),([0-9]+)$ ]]; then
  log "ligne de telemetrie invalide : $LIGNE"; exit 1
fi
MESURES=$(wc -l < "$SRC")

# ecriture atomique : fichier temporaire dans le meme dossier puis mv
TMP=$(mktemp "$WWW/.etat.json.XXXXXX")
cat > "$TMP" <<JSON
{
  "genere": "$(date --iso-8601=seconds)",
  "hote": "$(hostname -s)",
  "derniere_mesure": "${BASH_REMATCH[1]}",
  "charge_1min": ${BASH_REMATCH[2]},
  "mem_dispo_ko": ${BASH_REMATCH[3]},
  "mesures": $MESURES
}
JSON
chmod 0660 "$TMP"
mv -f "$TMP" "$DEST"
TMP=""
log "etat.json publie ($MESURES mesures)"
exit 0
