#!/bin/bash
set -e  # stop bij fouten

# Variabelen
FTP_SERVER="10.1.51.44"
FTP_FILE="Windows10Template.qcow2"
LOCAL_DIR="/opt/gns3/images/QEMU"

# Controleer of lftp aanwezig is, anders installeren
if ! command -v lftp &> /dev/null; then
    echo "lftp niet gevonden. Installeren..."
    sudo apt update
    sudo apt install -y lftp
fi

# Maak de doelmap aan
mkdir -p "$LOCAL_DIR"

# Download met lftp (anonymous, passive mode)
lftp -u anonymous, $FTP_SERVER <<EOF
set ftp:passive-mode on
lcd $LOCAL_DIR
get $FTP_FILE
bye
EOF

echo "Download voltooid: $LOCAL_DIR/$FTP_FILE"
