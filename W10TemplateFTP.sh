#!/bin/bash
set -e  # Stop het script direct bij een fout

# --- VARIABELEN ---
# FTP-instellingen
FTP_SERVER="10.1.51.44"
FTP_FILE="Windows10Template.qcow2"

# GNS3-instellingen
GNS3_IMAGE_DIR="/opt/gns3/images/QEMU"
GNS3_CONFIG_FILE="$HOME/.config/GNS3/2.2/gns3_controller.conf"
TEMPLATE_NAME="Windows10Template"
LOCAL_FILE_PATH="$GNS3_IMAGE_DIR/$FTP_FILE"

# De JSON-data voor de nieuwe template (in een variabele geplaatst)
# Let op: De JSON is hier 'minified' (alles op één regel) om het makkelijker in het script te verwerken.
TEMPLATE_JSON='{"name":"Windows10Template","default_name_format":"{name}-{0}","usage":"","symbol":"Microsoft_logo.svg","category":"guest","port_name_format":"Ethernet{0}","port_segment_size":0,"first_port_name":"","custom_adapters":[],"qemu_path":"/bin/qemu-system-x86_64","hda_disk_image":"Windows10Template.qcow2","hdb_disk_image":"","hdc_disk_image":"","hdd_disk_image":"","hda_disk_interface":"ide","hdb_disk_interface":"none","hdc_disk_interface":"none","hdd_disk_interface":"none","cdrom_image":"","bios_image":"","boot_priority":"c","console_type":"vnc","console_auto_start":false,"ram":2048,"cpus":2,"adapters":1,"adapter_type":"e1000","mac_address":null,"legacy_networking":false,"replicate_network_connection_state":true,"tpm":false,"uefi":false,"create_config_disk":false,"on_close":"shutdown_signal","platform":"","cpu_throttling":0,"process_priority":"normal","options":"","kernel_image":"","initrd":"","kernel_command_line":"","linked_clone":true,"compute_id":"local","template_id":"6a40307a-5da1-4add-bf22-6ed4a94a5606","template_type":"qemu","builtin":false}'

# --- CONTROLEER BENODIGDE SOFTWARE ---
# Controleer of lftp en jq aanwezig zijn, anders installeren
if ! command -v lftp &> /dev/null || ! command -v jq &> /dev/null; then
    echo "lftp en/of jq niet gevonden. Installeren..."
    sudo apt-get update
    sudo apt-get install -y lftp jq
fi

# --- STAP 1: DOWNLOAD DE IMAGE ---
echo "--- Stap 1: Controleren en downloaden van QEMU image ---"
if [ -f "$LOCAL_FILE_PATH" ]; then
    echo "✅ Image bestaat al: $LOCAL_FILE_PATH. Download wordt overgeslagen."
else
    echo "Image nog niet aanwezig. Downloadprocedure wordt gestart..."
    mkdir -p "$GNS3_IMAGE_DIR"
    lftp -u anonymous, $FTP_SERVER <<EOF
set ftp:passive-mode on
lcd $GNS3_IMAGE_DIR
get $FTP_FILE
bye
EOF
    echo "✅ Download voltooid: $LOCAL_FILE_PATH"
fi

# --- STAP 2: VOEG TEMPLATE TOE AAN GNS3 CONFIGURATIE ---
echo "" # Lege regel voor leesbaarheid
echo "--- Stap 2: Toevoegen van template aan GNS3 configuratie ---"

# Controleer of het configuratiebestand bestaat
if [ ! -f "$GNS3_CONFIG_FILE" ]; then
    echo "❌ FOUT: GNS3 configuratiebestand niet gevonden op $GNS3_CONFIG_FILE"
    exit 1
fi

# Controleer met jq of een template met deze naam al bestaat
if jq -e '.templates[] | select(.name == "'"$TEMPLATE_NAME"'")' "$GNS3_CONFIG_FILE" > /dev/null; then
    echo "✅ Template '$TEMPLATE_NAME' bestaat al in de configuratie. Actie overgeslagen."
else
    echo "Template '$TEMPLATE_NAME' nog niet aanwezig. Toevoegen..."
    # Gebruik jq om de nieuwe template vooraan de 'templates'-array toe te voegen.
    # Er wordt een tijdelijk bestand gemaakt om problemen tijdens het schrijven te voorkomen.
    jq --argjson new_template "$TEMPLATE_JSON" '.templates = [$new_template] + .templates' "$GNS3_CONFIG_FILE" > "$GNS3_CONFIG_FILE.tmp" && mv "$GNS3_CONFIG_FILE.tmp" "$GNS3_CONFIG_FILE"
    echo "✅ Template succesvol toegevoegd aan $GNS3_CONFIG_FILE"
fi

echo ""
echo "Script succesvol afgerond!"
