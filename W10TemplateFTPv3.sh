#!/bin/bash
set -e # Exit script immediately if a command exits with a non-zero status.

# --- VARIABLES ---
# GNS3 Paths and Names
GNS3_IMAGE_DIR="/opt/gns3/images/QEMU"
# Using the specific path as requested
GNS3_CONFIG_FILE="/home/gns3/.config/GNS3/2.2/gns3_controller.conf"
GNS3_SERVICE_NAME="gns3"

# Windows 10 Template Settings
FTP_SERVER="10.1.51.44"
WIN10_FTP_FILE="Windows10Template.qcow2"
WIN10_TEMPLATE_NAME="Windows10Template"
WIN10_LOCAL_FILE_PATH="$GNS3_IMAGE_DIR/$WIN10_FTP_FILE"
WIN10_TEMPLATE_JSON='{"name":"Windows10Template","default_name_format":"{name}-{0}","usage":"","symbol":"Microsoft_logo.svg","category":"guest","port_name_format":"Ethernet{0}","port_segment_size":0,"first_port_name":"","custom_adapters":[],"qemu_path":"/bin/qemu-system-x86_64","hda_disk_image":"Windows10Template.qcow2","hdb_disk_image":"","hdc_disk_image":"","hdd_disk_image":"","hda_disk_interface":"ide","hdb_disk_interface":"none","hdc_disk_interface":"none","hdd_disk_interface":"none","cdrom_image":"","bios_image":"","boot_priority":"c","console_type":"vnc","console_auto_start":false,"ram":2048,"cpus":2,"adapters":1,"adapter_type":"e1000","mac_address":null,"legacy_networking":false,"replicate_network_connection_state":true,"tpm":false,"uefi":false,"create_config_disk":false,"on_close":"shutdown_signal","platform":"","cpu_throttling":0,"process_priority":"normal","options":"","kernel_image":"","initrd":"","kernel_command_line":"","linked_clone":true,"compute_id":"local","template_id":"6a40307a-5da1-4add-bf22-6ed4a94a5606","template_type":"qemu","builtin":false}'

# Windows 11 Removal Settings
WIN11_IMAGE_PATTERN="Windows11Preset.*"
WIN11_TEMPLATE_NAME="Windows11"

# --- CHECK REQUIRED SOFTWARE ---
if ! command -v lftp &> /dev/null || ! command -v jq &> /dev/null; then
    echo "lftp and/or jq not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y lftp jq
fi

# --- OPTIONAL: REMOVE WINDOWS 11 TEMPLATE ---
echo "--- Optional: Remove Windows 11 Template ---"
# Ask user for input
read -p "Do you want to remove the Windows 11 template? (yes/no): " user_choice

# Check user's answer (case-insensitive)
if [[ "$user_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Proceeding with removal of Windows 11 files and template..."
    
    # 1. Remove image files
    echo "--> Removing image files: $GNS3_IMAGE_DIR/$WIN11_IMAGE_PATTERN"
    # Use -f to avoid errors if files do not exist
    sudo rm -f "$GNS3_IMAGE_DIR/$WIN11_IMAGE_PATTERN"

    # 2. Remove template from config file
    echo "--> Removing '$WIN11_TEMPLATE_NAME' from $GNS3_CONFIG_FILE..."
    if [ -f "$GNS3_CONFIG_FILE" ] && jq -e --arg name "$WIN11_TEMPLATE_NAME" '.templates[] | select(.name == $name)' "$GNS3_CONFIG_FILE" > /dev/null; then
        # Template exists, remove it
        jq --arg name "$WIN11_TEMPLATE_NAME" 'del(.templates[] | select(.name == $name))' "$GNS3_CONFIG_FILE" > "$GNS3_CONFIG_FILE.tmp" && sudo mv "$GNS3_CONFIG_FILE.tmp" "$GNS3_CONFIG_FILE"
        sudo chown gns3:gns3 "$GNS3_CONFIG_FILE"
        sudo chmod 664 "$GNS3_CONFIG_FILE"
        echo "--> Restarting GNS3 service to apply changes..."
        sudo systemctl restart "$GNS3_SERVICE_NAME"
        echo "✅ Windows 11 template successfully removed."
    else
        echo "Template '$WIN11_TEMPLATE_NAME' not found in configuration, skipping."
    fi
else
    echo "Skipping removal of Windows 11 template."
fi
echo "----------------------------------------------"
echo ""


# --- STEP 1: DOWNLOAD THE WINDOWS 10 IMAGE ---
echo "--- Step 1: Checking and downloading Windows 10 QEMU image ---"
if [ -f "$WIN10_LOCAL_FILE_PATH" ]; then
    echo "✅ Image already exists: $WIN10_LOCAL_FILE_PATH. Skipping download."
else
    echo "Image not found. Starting download procedure..."
    mkdir -p "$GNS3_IMAGE_DIR"
    lftp -u anonymous, $FTP_SERVER <<EOF
set ftp:passive-mode on
lcd $GNS3_IMAGE_DIR
get $WIN10_FTP_FILE
bye
EOF
    echo "✅ Download complete: $WIN10_LOCAL_FILE_PATH"
fi

# --- STEP 2: ADD WINDOWS 10 TEMPLATE TO GNS3 CONFIGURATION ---
echo ""
echo "--- Step 2: Adding Windows 10 template to GNS3 configuration ---"

if [ ! -f "$GNS3_CONFIG_FILE" ]; then
    echo "❌ ERROR: GNS3 configuration file not found at $GNS3_CONFIG_FILE"
    exit 1
fi

NEEDS_POST_CONFIG_STEPS=false
if jq -e --arg name "$WIN10_TEMPLATE_NAME" '.templates[] | select(.name == $name)' "$GNS3_CONFIG_FILE" > /dev/null; then
    echo "✅ Template '$WIN10_TEMPLATE_NAME' already exists in the configuration. Skipping action."
else
    echo "Template '$WIN10_TEMPLATE_NAME' not found. Adding..."
    jq --argjson new_template "$WIN10_TEMPLATE_JSON" '.templates = [$new_template] + .templates' "$GNS3_CONFIG_FILE" > "$GNS3_CONFIG_FILE.tmp" && sudo mv "$GNS3_CONFIG_FILE.tmp" "$GNS3_CONFIG_FILE"
    echo "✅ Template successfully added to $GNS3_CONFIG_FILE"
    NEEDS_POST_CONFIG_STEPS=true
fi

# --- STEP 3: SET PERMISSIONS AND RESTART SERVICE (if needed for Win10) ---
echo ""
echo "--- Step 3: Finalizing configuration for Windows 10 ---"
if [ "$NEEDS_POST_CONFIG_STEPS" = true ]; then
    echo "Setting owner and permissions for configuration file..."
    sudo chown gns3:gns3 "$GNS3_CONFIG_FILE"
    sudo chmod 664 "$GNS3_CONFIG_FILE"
    echo "✅ Owner and permissions set correctly."

    echo "Restarting GNS3 service to apply changes..."
    sudo systemctl restart "$GNS3_SERVICE_NAME"
    echo "✅ GNS3 service has been restarted."
else
    echo "No changes were made for the Windows 10 template; subsequent steps are not required."
fi

echo ""
echo "Script finished successfully!"
