#!/usr/bin/env bash

# Backup current sources.list with timestamp
backup_file="/etc/apt/sources.list-$(date -Iseconds)"
cp /etc/apt/sources.list "$backup_file"
echo "Created backup: $backup_file"

# Install netselect-apt if not present
if ! command -v netselect-apt &> /dev/null; then
    apt-get update
    apt-get install -y netselect-apt
fi

# Create temporary directory
temp_dir=$(mktemp -d)
cd "$temp_dir" || exit 1

# Use netselect-apt to find fastest mirrors and generate new sources.list
# -n: non-interactive
# -o: output file
# -a: architecture (get current)
arch=$(dpkg --print-architecture)
netselect-apt -n -a "$arch" -o sources.list

# Check if new sources.list was created successfully
if [ -f sources.list ]; then
    # Replace the old sources.list with the new one
    mv sources.list /etc/apt/sources.list
    echo "Updated sources.list with fastest mirrors"
    
    # Update package lists to use new mirrors
    apt-get update
else
    echo "Failed to generate new sources.list"
    exit 1
fi

# Cleanup
cd - || exit 1
rm -rf "$temp_dir"