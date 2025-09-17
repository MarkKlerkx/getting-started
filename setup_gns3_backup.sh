#!/bin/bash

# Logfile
LOGFILE="/var/log/gns3_backup.log"

# Datum en tijd
NOW=$(date +"%Y-%m-%d %H:%M:%S")

# Logfunctie
log() {
    echo "[$NOW] $1" >> "$LOGFILE"
}

# Start loggen
log "Backup gestart"

SRC_DIR="/opt/gns3/projects"
DEST_DIR="/gns-backup"
STAMP=$(date +"%Y%m%d-%H%M%S")

# Zoek en kopieer alle .gns3-bestanden
if [ -d "$SRC_DIR" ]; then
    find "$SRC_DIR" -type f -name "*.gns3" | while read FILE; do
        BASENAME=$(basename "$FILE" .gns3)
        DESTFILE="$DEST_DIR/${BASENAME}_$STAMP.gns3"
        if cp "$FILE" "$DESTFILE" 2>>"$LOGFILE"; then
            log "Gekopieerd: $FILE → $DESTFILE"
        else
            log "FOUT bij kopiëren: $FILE"
        fi
    done
else
    log "FOUT: bronmap $SRC_DIR bestaat niet"
fi

# Verwijder bestanden ouder dan 5 dagen
if find "$DEST_DIR" -type f -name "*.gns3" -mtime +5 -exec rm -f {} \; 2>>"$LOGFILE"; then
    log "Oude bestanden (>5 dagen) verwijderd"
else
    log "FOUT bij verwijderen oude bestanden"
fi

log "Backup klaar"
echo "" >> "$LOGFILE"
