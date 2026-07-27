#!/bin/bash
set -e

SDK_DIR="/home/meheraj/flutter"
DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.2-stable.tar.xz"
DOWNLOAD_DEST="/home/meheraj/Downloads/flutter_linux_3.22.2-stable.tar.xz"

echo "Checking Flutter SDK installation..."

if [ -d "$SDK_DIR/bin" ]; then
    echo "Flutter SDK is already installed in $SDK_DIR"
else
    echo "Flutter SDK not found. Preparing download..."
    mkdir -p "/home/meheraj/Downloads"
    
    if [ ! -f "$DOWNLOAD_DEST" ]; then
        echo "Downloading Flutter SDK..."
        curl -o "$DOWNLOAD_DEST" "$DOWNLOAD_URL"
    else
        echo "Found existing download archive."
    fi
    
    echo "Extracting Flutter SDK to /home/meheraj/..."
    tar -xf "$DOWNLOAD_DEST" -C "/home/meheraj"
    echo "Extraction complete."
fi

# Set PATH for verification in this script execution
export PATH="$SDK_DIR/bin:$PATH"

echo "Verifying Flutter SDK version..."
flutter --version

echo "Flutter SDK Setup finished successfully!"
