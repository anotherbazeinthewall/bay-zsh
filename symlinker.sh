#!/bin/zsh

echo

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
BACKUP_DIR="$SCRIPT_DIR/backups"
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")

printf "This setup script will back up your current ~/.zshrc to a folder within the repo and replace it with a symlink to $SCRIPT_DIR/.zshrc, then reload it to apply the changes immediately. From now on, any changes made to $SCRIPT_DIR/.zshrc will automatically reflect in your shell configuration. You won't need to manually update or move files—just edit the repo's .zshrc, and the changes will be active the next time you start a new terminal session (or immediately if you reload with source ~/.zshrc).\n\nWould you like to proceed with the setup? (y/n): "
read user_response

# Check if the user response is 'y' or 'yes'
if [[ $user_response =~ ^[Yy]$ ]]; then
    echo "\nProceeding with the setup..."
else
    echo "Setup aborted."
    exit 1
fi

echo "🔍 Checking for existing ~/.zshrc..."
if [ -e ~/.zshrc ]; then
    if [ -L ~/.zshrc ]; then
        # ~/.zshrc is a symlink, so back up the file it points to
        TARGET=$(readlink ~/.zshrc)
        echo "📦 Found ~/.zshrc as a symlink to $TARGET. Backing up the target file to $BACKUP_DIR/zshrc_backup_$BACKUP_DATE"

        if [ ! -d "$BACKUP_DIR" ]; then
            echo "📁 Creating backup directory at $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR"
        fi

        cp "$TARGET" "$BACKUP_DIR/zshrc_backup_$BACKUP_DATE"
    else
        # ~/.zshrc is a regular file, so back it up
        echo "📦 Found existing ~/.zshrc, backing up to $BACKUP_DIR/zshrc_backup_$BACKUP_DATE"

        if [ ! -d "$BACKUP_DIR" ]; then
            echo "📁 Creating backup directory at $BACKUP_DIR"
            mkdir -p "$BACKUP_DIR"
        fi

        mv ~/.zshrc "$BACKUP_DIR/zshrc_backup_$BACKUP_DATE"
    fi
fi

echo "🔗 Creating symlink from ~/.zshrc to $SCRIPT_DIR/.zshrc"
ln -sf $SCRIPT_DIR/.zshrc ~/.zshrc

echo "🔄 Sourcing new .zshrc...\n"

source ~/.zshrc
