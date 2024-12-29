#!/data/data/com.termux/files/usr/bin/bash

echo "Boot Images Extractor for Magisk"
echo "------------------------------"

# Navigate to internal storage
cd /sdcard

echo "Searching for payload.bin in internal storage..."

# Find all payload.bin files in storage
PAYLOAD_FILES=($(find . -name "payload.bin" 2>/dev/null))

# Check if any payload.bin files were found
if [ ${#PAYLOAD_FILES[@]} -eq 0 ]; then
    echo "Error: No payload.bin found in internal storage"
    echo "Please place payload.bin in your internal storage and try again"
    exit 1
fi

# If multiple payload.bin files are found, let user choose
if [ ${#PAYLOAD_FILES[@]} -gt 1 ]; then
    echo "Multiple payload.bin files found:"
    for i in "${!PAYLOAD_FILES[@]}"; do
        echo "[$i] ${PAYLOAD_FILES[$i]}"
    done
    
    read -p "Enter the number of the payload.bin you want to use: " CHOICE
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "${#PAYLOAD_FILES[@]}" ]; then
        echo "Invalid choice"
        exit 1
    fi
    PAYLOAD_PATH="${PAYLOAD_FILES[$CHOICE]}"
else
    PAYLOAD_PATH="${PAYLOAD_FILES[0]}"
fi

echo "Using payload.bin from: $PAYLOAD_PATH"
cd "$(dirname "$PAYLOAD_PATH")"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Installing required package: $2"
        pkg install -y "$2"
    fi
}

# Install required packages
check_command "python" "python"
check_command "git" "git"

# Check if payload-dumper-go is already installed
if ! command -v "payload-dumper-go" &> /dev/null; then
    echo "Installing payload-dumper-go..."
    
    # Install golang if not present
    check_command "go" "golang"
    
    # Create temporary directory for building
    BUILD_DIR="$(mktemp -d)"
    cd "$BUILD_DIR"
    
    # Clone and build payload-dumper-go
    git clone https://github.com/ssut/payload-dumper-go.git
    cd payload-dumper-go
    go build
    mv payload-dumper-go $PREFIX/bin/
    cd
    rm -rf "$BUILD_DIR"
    
    # Return to payload directory
    cd "$(dirname "$PAYLOAD_PATH")"
fi

echo "Extracting boot and vendor_boot images from payload.bin..."
payload-dumper-go -p boot.img,vendor_boot.img "$(basename "$PAYLOAD_PATH")"

# Check which images were extracted
EXTRACTED_FILES=""
if [ -f "boot.img" ]; then
    BOOT_HASH=$(sha256sum boot.img | cut -d' ' -f1)
    EXTRACTED_FILES+="boot.img"
fi
if [ -f "vendor_boot.img" ]; then
    VENDOR_BOOT_HASH=$(sha256sum vendor_boot.img | cut -d' ' -f1)
    if [ -n "$EXTRACTED_FILES" ]; then
        EXTRACTED_FILES+=", "
    fi
    EXTRACTED_FILES+="vendor_boot.img"
fi

if [ -z "$EXTRACTED_FILES" ]; then
    echo "Error: Failed to extract boot images from payload.bin"
    exit 1
fi

echo -e "\nExtraction completed successfully!"
echo "Extracted files: $EXTRACTED_FILES"
echo "Location: $(pwd)"

if [ -f "boot.img" ]; then
    echo -e "\nboot.img SHA256: $BOOT_HASH"
fi
if [ -f "vendor_boot.img" ]; then
    echo -e "vendor_boot.img SHA256: $VENDOR_BOOT_HASH"
fi

echo -e "\nNext steps for Magisk:"
echo "1. Open Magisk Manager"
echo "2. Tap Install → Select and Patch a File"
echo "3. Navigate to this directory and select boot.img"
echo -e "\nNote: If Magisk asks for vendor_boot.img, it's also been extracted"

# Create a verification script
cat > verify_images.sh << EOL
#!/data/data/com.termux/files/usr/bin/bash
if [ -f "boot.img" ]; then
    echo "${BOOT_HASH}  boot.img" | sha256sum -c -
fi
if [ -f "vendor_boot.img" ]; then
    echo "${VENDOR_BOOT_HASH}  vendor_boot.img" | sha256sum -c -
fi
EOL
chmod +x verify_images.sh

echo -e "\nA verification script 'verify_images.sh' has been created in the same directory"
