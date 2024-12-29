#!/data/data/com.termux/files/usr/bin/bash

echo "Boot and Vendor Boot Extractor for Magisk"
echo "---------------------------------------"

# Navigate to internal storage
cd /sdcard || {
    echo "Error: Cannot access /sdcard"
    exit 1
}

echo "Searching for payload.bin..."

# Find payload.bin files
PAYLOAD_FILES=($(find . -name "payload.bin" 2>/dev/null))

# Check if any payload.bin files were found
if [ ${#PAYLOAD_FILES[@]} -eq 0 ]; then
    echo "Error: No payload.bin found in storage"
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

# Get the directory of the chosen payload.bin
TARGET_DIR=$(dirname "$PAYLOAD_PATH")
echo "Using payload.bin from: $PAYLOAD_PATH"
cd "$TARGET_DIR" || {
    echo "Error: Cannot access target directory"
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Installing required package: $2"
        pkg install -y "$2" || {
            echo "Error: Failed to install $2"
            exit 1
        }
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
    BUILD_DIR="/data/data/com.termux/files/home/temp_build"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || exit 1
    
    # Clone and build payload-dumper-go
    git clone https://github.com/ssut/payload-dumper-go.git
    cd payload-dumper-go || exit 1
    go build
    mv payload-dumper-go $PREFIX/bin/
    cd "$TARGET_DIR" || exit 1
    rm -rf "$BUILD_DIR"
fi

echo "Starting extraction..."

# Create a clean extraction directory
EXTRACT_DIR="boot_images_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EXTRACT_DIR"
cd "$EXTRACT_DIR" || exit 1

echo "Extracting boot.img and vendor_boot.img..."
cp "../$(basename "$PAYLOAD_PATH")" ./ || {
    echo "Error: Failed to copy payload.bin"
    exit 1
}

# Extract the images
payload-dumper-go -p boot.img,vendor_boot.img payload.bin || {
    echo "Error during extraction"
    cd ..
    rm -rf "$EXTRACT_DIR"
    exit 1
}

# Move back to parent directory and cleanup
cd ..

# Check if files were extracted successfully
if [ ! -f "$EXTRACT_DIR/boot.img" ] || [ ! -f "$EXTRACT_DIR/vendor_boot.img" ]; then
    echo "Error: Failed to extract one or both boot images"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

# Move files to target directory
mv "$EXTRACT_DIR/boot.img" ./ || {
    echo "Error: Failed to move boot.img"
    exit 1
}

mv "$EXTRACT_DIR/vendor_boot.img" ./ || {
    echo "Error: Failed to move vendor_boot.img"
    exit 1
}

# Cleanup extraction directory
rm -rf "$EXTRACT_DIR"

# Calculate hashes
BOOT_HASH=$(sha256sum boot.img | cut -d' ' -f1)
VENDOR_BOOT_HASH=$(sha256sum vendor_boot.img | cut -d' ' -f1)

echo -e "\nExtraction completed successfully!"
echo "Files have been extracted to: $(pwd)"
echo "boot.img size: $(ls -lh boot.img | awk '{print $5}')"
echo "vendor_boot.img size: $(ls -lh vendor_boot.img | awk '{print $5}')"
echo -e "\nFile hashes:"
echo "boot.img: $BOOT_HASH"
echo "vendor_boot.img: $VENDOR_BOOT_HASH"

echo -e "\nNext steps for Magisk:"
echo "1. Open Magisk Manager"
echo "2. Tap Install → Select and Patch a File"
echo "3. Navigate to $(pwd)"
echo "4. Select boot.img"
echo "Note: vendor_boot.img is also available if needed"

# Create verification script
cat > verify_images.sh << EOL
#!/data/data/com.termux/files/usr/bin/bash
echo "${BOOT_HASH}  boot.img" | sha256sum -c -
echo "${VENDOR_BOOT_HASH}  vendor_boot.img" | sha256sum -c -
EOL
chmod +x verify_images.sh

echo -e "\nA verification script 'verify_images.sh' has been created"
