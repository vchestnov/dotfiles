#!/bin/bash

# Fix the cargo directory structure
# This script fixes the issue where .cargo was moved into cargo/.cargo

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CARGO_DIR="$XDG_DATA_HOME/cargo"

echo "Fixing cargo directory structure..."

# Check if the problematic structure exists
if [ -d "$CARGO_DIR/.cargo" ]; then
    echo "Found problematic structure: $CARGO_DIR/.cargo"
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    echo "Using temporary directory: $TEMP_DIR"
    
    # Move the nested .cargo contents to temp
    mv "$CARGO_DIR/.cargo"/* "$TEMP_DIR/" 2>/dev/null
    mv "$CARGO_DIR/.cargo"/.[!.]* "$TEMP_DIR/" 2>/dev/null  # Move hidden files
    
    # Remove the empty .cargo directory
    rmdir "$CARGO_DIR/.cargo"
    
    # Move everything back to the correct location
    mv "$TEMP_DIR"/* "$CARGO_DIR/" 2>/dev/null
    mv "$TEMP_DIR"/.[!.]* "$CARGO_DIR/" 2>/dev/null  # Move hidden files back
    
    # Clean up temp directory
    rmdir "$TEMP_DIR"
    
    echo "✓ Fixed cargo directory structure"
    echo "Contents are now directly in: $CARGO_DIR"
    
else
    echo "No problematic structure found. Directory structure is correct."
fi

# Verify the fix
echo
echo "Current cargo directory contents:"
ls -la "$CARGO_DIR" | head -10
