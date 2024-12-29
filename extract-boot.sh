#!/data/data/com.termux/files/usr/bin/bash

echo "Boot.img Extractor for Magisk"
echo "----------------------------"

# Setup storage access if not already done
if [ ! -d ~/storage ]; then
    echo "Setting up storage access..."
    termux-setup-storage
    
    # Wait for user to grant permission
    echo "Please grant storage permission in the popup"
    sleep 5
    
    # Check if storage was properly setup
    if [ ! -d ~/storage ]; then
        echo "Error: Storage access not granted. Please run 'termux-setup-storage' manually and try again."
        exit 1
    fi
fi

# Navigate to internal storage
cd ~/storage/shared

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

echo "Extracting boot.img from payload.bin..."
payload-dumper-go -p boot.img "$(basename "$PAYLOAD_PATH")"

# Check if boot.img was extracted
if [ ! -f "boot.img" ]; then
    echo "Error: Failed to extract boot.img from payload.bin"
    exit 1
fi

# Calculate SHA256 hash for verification
BOOT_HASH=$(sha256sum boot.img | cut -d' ' -f1)

echo -e "\nExtraction completed successfully!"
echo "boot.img has been extracted to: $(pwd)/boot.img"
echo "SHA256: $BOOT_HASH"
echo -e "\nNext steps:"
echo "1. Open Magisk Manager"
echo "2. Tap Install → Select and Patch a File"
echo "3. Navigate to this directory and select boot.img"
echo -e "\nTo verify the original boot.img integrity later, use:"
echo "echo \"$BOOT_HASH\" | sha256sum -c -"

# Create a simple verification script
cat > verify_boot.sh << EOL
#!/data/data/com.termux/files/usr/bin/bash
echo "${BOOT_HASH}  boot.img" | sha256sum -c -
EOL
chmod +x verify_boot.sh

echo -e "\nA verification script 'verify_boot.sh' has been created in the same directory"
