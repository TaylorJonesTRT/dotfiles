#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is stored
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d%H%M%S)"

# Print with color
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .config directory exists, if not create it
if [ ! -d "$CONFIG_DIR" ]; then
    print_info "Creating .config directory in $HOME"
    mkdir -p "$CONFIG_DIR"
fi

# Create backup directory if we need to backup files
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "Creating backup directory at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
}

# Function to create symlinks
create_symlinks() {
    print_info "Creating symlinks from dotfiles to $CONFIG_DIR"
    
    # Loop through all directories in the config directory of the dotfiles repo
    for src_dir in "$DOTFILES_DIR"/config/*/; do
        if [ -d "$src_dir" ]; then
            dir_name=$(basename "$src_dir")
            target_dir="$CONFIG_DIR/$dir_name"
            
            # If target directory already exists but is not a symlink
            if [ -d "$target_dir" ] && [ ! -L "$target_dir" ]; then
                create_backup_dir
                print_warning "$target_dir already exists, backing up to $BACKUP_DIR/$dir_name"
                mv "$target_dir" "$BACKUP_DIR/$dir_name"
            elif [ -L "$target_dir" ]; then
                print_warning "$target_dir is already a symlink. Removing it."
                rm "$target_dir"
            fi
            
            print_info "Creating symlink for $dir_name"
            ln -sf "$src_dir" "$target_dir"
        fi
    done
}

# Main execution
print_info "Starting dotfiles installation"
create_symlinks
print_info "Dotfiles installation completed successfully!"
