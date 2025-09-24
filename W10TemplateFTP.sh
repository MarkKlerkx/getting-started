#!/bin/bash

# ==============================================================================
# Script voor het configureren en voorbereiden van de Windows 10 GNS3 Template
#
# Acties:
# 1. Voegt de 'Windows10Template' configuratie toe aan gns3_controller.conf.
# 2. Controleert of de 'Windows10Template.qcow2' image al bestaat.
# 3. Indien de image niet bestaat, wordt deze gedownload van een FTP server.
# ==============================================================================

# --- Configuratie Variabelen ---

# Pas deze variabelen aan naar jouw situatie
FTP_SERVER="ftp://jouw.server.adres"
FTP_USER="jouwgebruikersnaam"
FTP_PASS="jouwsterkewachtwoord"
FTP_REMOTE_PATH="/pad/op/server/naar/Windows10Template.qcow2"

# GNS3 & Image paden
GNS3_CONFIG_FILE="$HOME/.config/GNS3/2.2/gns3_controller.conf"
IMAGE_DIR="/opt/gns3/images/QEMU"
IMAGE_NAME="Windows10Template.qcow2"
FULL_IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME"

# De JSON-configuratie voor de nieuwe template.
read -r -d '' NEW_TEMPLATE_JSON <<'EOF'
      {
          "name": "Windows10Template",
          "default_name_format": "{name}-{0}",
          "usage": "",
          "symbol": "Microsoft_logo.svg",
          "category": "guest",
          "port_name_format": "Ethernet{0}",
          "port_segment_size": 0,
          "first_port_name": "",
          "custom_adapters": [],
          "qemu_path": "/bin/qemu-system-x86_64",
          "hda_disk_image": "Windows10Template.qcow2",
          "hdb_disk_image": "",
          "hdc_disk_image": "",
          "hdd_disk_image": "",
          "hda_disk_interface": "ide",
          "hdb_disk_interface": "none",
          "hdc_disk_interface": "none",
          "hdd_disk_interface": "none",
          "cdrom_image": "",
          "bios_image": "",
          "boot_priority": "c",
          "console_type": "vnc",
          "console_auto_start": false,
          "ram": 2048,
          "cpus": 2,
          "adapters": 1,
          "adapter_type": "e1000",
          "mac_address": null,
          "legacy_networking": false,
          "replicate_network_connection_state": true,
          "tpm": false,
          "uefi": false,
          "create_config_disk": false,
          "on_close": "power_off",
          "platform": "",
          "cpu_throttling": 0,
          "process_priority": "normal",
          "options": "",
          "kernel_image": "",
          "initrd": "",
          "kernel_command_line": "",
          "linked_clone": true,
          "compute_id": "local",
          "template_id": "6a40307a-5da1-4add-bf22-6ed4a94a5606",
          "template_type": "qemu",
          "builtin": false
      },
EOF

# --- Script Start ---

# Sectie 1: GNS3 Configuratie aanpassen
echo "--- Sectie 1: GNS3 Configuratie ---"

if [ ! -f "$GNS3_CONFIG_FILE" ]; then
    echo "FOUT: GNS3 configuratiebestand niet gevonden op '$GNS3_CONFIG_FILE'."
    exit 1
fi

if grep -q '"name": "Windows10Template"' "$GNS3_CONFIG_FILE"; then
    echo "INFO: De 'Windows10Template' bestaat al in de configuratie. Er wordt niets gewijzigd."
else
    echo "-> De 'Windows10Template' aan het configuratiebestand toevoegen..."
    awk -v template="$NEW_TEMPLATE_JSON" '
        /\[templates\]/ { print; print template; next }
        { print }
    ' "$GNS3_CONFIG_FILE" > "${GNS3_CONFIG_FILE}.tmp" && mv "${GNS3_CONFIG_FILE}.tmp" "$GNS3_CONFIG_FILE"
    echo "SUCCES: De template is toegevoegd aan '$GNS3_CONFIG_FILE'."
fi
echo "" # Lege regel voor leesbaarheid

# Sectie 2: Controleer en Download de Image
echo "--- Sectie 2: QEMU Image Controle ---"

# Controleer of de image al bestaat
if [ -f "$FULL_IMAGE_PATH" ]; then
    echo "INFO: Image '$IMAGE_NAME' bestaat al op de locatie '$IMAGE_DIR'."
    echo "Download wordt overgeslagen."
    # Het script kan hier stoppen of doorgaan met andere taken
else
    echo "WAARSCHUWING: Image '$IMAGE_NAME' niet gevonden."
    echo "-> Starten met downloaden van FTP server..."

    # Zorg ervoor dat de doelmap bestaat
    mkdir -p "$IMAGE_DIR"

    # Gebruik wget om het bestand te downloaden.
    # De output (-O) wordt direct naar de juiste map en bestandsnaam geschreven.
    wget -c --user="$FTP_USER" --password="$FTP_PASS" "$FTP_SERVER$FTP_REMOTE_PATH" -O "$FULL_IMAGE_PATH"

    # Controleer of de download succesvol was
    if [ $? -eq 0 ]; then
        echo "SUCCES: De image is succesvol gedownload naar '$FULL_IMAGE_PATH'."
    else
        echo "FOUT: Er is iets misgegaan tijdens het downloaden. Controleer de FTP-gegevens en het pad."
        exit 1
    fi
fi

echo ""
echo "Script voltooid. Je kunt GNS3 nu starten."
exit 0
