#!/bin/bash
#
# This script builds all components of the GestureControlPro project.
# It stops immediately if any command fails.

set -e

echo "--- Starting GestureControlPro Build Process ---"

# 1. Build Swift Application
echo "\n[1/3] Building Swift application (GestureControlPro)..."
if ! command -v xcodebuild &> /dev/null; then
    echo "xcodebuild command not found. Skipping Swift application build."
    echo "Please run this on a macOS machine with Xcode installed to build the application."
elif [ -d "GestureControlPro.xcodeproj" ]; then
    xcodebuild build -project GestureControlPro.xcodeproj -scheme GestureControlPro -configuration Release
    echo "Swift application built successfully."
else
    echo "Xcode project not found. Skipping Swift build."
fi

# 2. Install Python Server Dependencies
echo "\n[2/2] Installing Python server dependencies..."
if [ -f "Server/Python/requirements.txt" ]; then
    pip install -r Server/Python/requirements.txt
    echo "Python dependencies installed successfully."
else
    echo "requirements.txt not found. Skipping Python dependencies."
fi

echo "\n--- Build Process Completed Successfully ---"
