#!/bin/bash

# ============================================
# Vaultwarden Restore Script
# ============================================
# Save this as: /root/scripts/vaultwarden-restore.sh
# Make executable: chmod +x /root/scripts/vaultwarden-restore.sh
# Usage: ./vaultwarden-restore.sh [backup_file.tar.gz]
# ============================================

# Configuration
DATA_DIR="/vw-data"  # Your actual data directory
VAULTWARDEN_DIR="/root/vaultwarden"  # Where your docker-compose.yml is located
BACKUP_DIR="/root/vw-backups"
CONTAINER_NAME="vaultwarden"
TEMP_RESTORE_DIR="/tmp/vaultwarden_restore_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${2}[$(date '+%Y-%m-%d %H:%M:%S')] ${1}${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    exit 1
fi

# Detect docker compose command
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    print_message "Using docker compose (new version)" "$BLUE"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    print_message "Using docker-compose (old version)" "$BLUE"
else
    print_message "ERROR: Neither 'docker compose' nor 'docker-compose' found!" "$RED"
    exit 1
fi

# Check if sqlite3 is available
HAS_SQLITE3=false
if command -v sqlite3 &> /dev/null; then
    HAS_SQLITE3=true
fi

# Function to list available backups
list_backups() {
    print_message "Available backups in $BACKUP_DIR:" "$CYAN"
    echo
    if ls "$BACKUP_DIR"/vaultwarden_backup_*.tar.gz 1> /dev/null 2>&1; then
        ls -lht "$BACKUP_DIR"/vaultwarden_backup_*.tar.gz | nl -v 1 | head -20
    else
        print_message "No backups found in $BACKUP_DIR" "$RED"
        exit 1
    fi
}

# Function to verify backup file
verify_backup_file() {
    local backup_file="$1"
    
    print_message "Verifying backup file..." "$YELLOW"
    
    # Check if file exists
    if [ ! -f "$backup_file" ]; then
        return 1
    fi
    
    # Check if it's a valid tar.gz
    if ! tar -tzf "$backup_file" &> /dev/null; then
        print_message "ERROR: Invalid or corrupted backup file!" "$RED"
        return 1
    fi
    
    # Check for required files in backup
    local required_files=("db.sqlite3" "backup_info.txt")
    for file in "${required_files[@]}"; do
        if ! tar -tzf "$backup_file" | grep -q "$file"; then
            print_message "WARNING: Backup missing $file" "$YELLOW"
        fi
    done
    
    return 0
}

# Get backup file
if [ -z "$1" ]; then
    print_message "No backup file specified!" "$YELLOW"
    echo
    list_backups
    echo
    read -p "Enter the number from the list or full path to backup file: " BACKUP_INPUT
    
    # Check if input is a number
    if [[ "$BACKUP_INPUT" =~ ^[0-9]+$ ]]; then
        BACKUP_FILE=$(ls -t "$BACKUP_DIR"/vaultwarden_backup_*.tar.gz 2>/dev/null | sed -n "${BACKUP_INPUT}p")
        if [ -z "$BACKUP_FILE" ]; then
            print_message "Invalid selection!" "$RED"
            exit 1
        fi
    else
        BACKUP_FILE="$BACKUP_INPUT"
    fi
else
    BACKUP_FILE="$1"
fi

# Verify backup file
if ! verify_backup_file "$BACKUP_FILE"; then
    print_message "ERROR: Backup file not found or invalid: $BACKUP_FILE" "$RED"
    exit 1
fi

print_message "Using backup file: $BACKUP_FILE" "$GREEN"
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
print_message "Backup size: $BACKUP_SIZE" "$BLUE"

# Extract backup info if available
print_message "Extracting backup information..." "$YELLOW"
tar -xzf "$BACKUP_FILE" -O "*/backup_info.txt" 2>/dev/null | head -20 || print_message "No backup info found (older backup format)" "$YELLOW"

# Critical warning
echo
print_message "═══════════════════════════════════════════════════════════" "$RED"
print_message "                    ⚠️  CRITICAL WARNING ⚠️                  " "$RED"
print_message "═══════════════════════════════════════════════════════════" "$RED"
print_message "This will COMPLETELY REPLACE your current Vaultwarden data!" "$RED"
print_message "Current passwords, 2FA codes, and settings will be DELETED!" "$RED"
print_message "═══════════════════════════════════════════════════════════" "$RED"
echo

# Show current status
print_message "Current Vaultwarden status:" "$CYAN"
if docker ps | grep -q "$CONTAINER_NAME"; then
    print_message "  Container: RUNNING" "$GREEN"
else
    print_message "  Container: STOPPED" "$YELLOW"
fi

if [ -f "$DATA_DIR/db.sqlite3" ]; then
    CURRENT_DB_SIZE=$(du -h "$DATA_DIR/db.sqlite3" | cut -f1)
    CURRENT_DB_DATE=$(stat -c %y "$DATA_DIR/db.sqlite3" | cut -d' ' -f1,2 | cut -d'.' -f1)
    print_message "  Current database: $CURRENT_DB_SIZE (Modified: $CURRENT_DB_DATE)" "$BLUE"
fi

echo
read -p "Type 'RESTORE' to proceed or anything else to cancel: " CONFIRM

if [ "$CONFIRM" != "RESTORE" ]; then
    print_message "Restore cancelled." "$YELLOW"
    exit 0
fi

# Create temporary directory
print_message "Creating temporary restore directory..." "$YELLOW"
mkdir -p "$TEMP_RESTORE_DIR"

# Extract backup
print_message "Extracting backup archive..." "$YELLOW"
tar -xzf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"

# Find the backup subdirectory
BACKUP_SUBDIR=$(find "$TEMP_RESTORE_DIR" -type d -name "backup_*" | head -1)

if [ ! -d "$BACKUP_SUBDIR" ]; then
    print_message "ERROR: Invalid backup structure!" "$RED"
    rm -rf "$TEMP_RESTORE_DIR"
    exit 1
fi

# Verify critical files exist in backup
print_message "Verifying backup contents..." "$YELLOW"
if [ ! -f "$BACKUP_SUBDIR/db.sqlite3" ]; then
    print_message "ERROR: No database file in backup!" "$RED"
    rm -rf "$TEMP_RESTORE_DIR"
    exit 1
fi

if [ ! -f "$BACKUP_SUBDIR/rsa_key.pem" ]; then
    print_message "WARNING: No RSA key in backup - you may not be able to decrypt data!" "$YELLOW"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        rm -rf "$TEMP_RESTORE_DIR"
        exit 1
    fi
fi

# Test database integrity if sqlite3 is available
if [ "$HAS_SQLITE3" = true ]; then
    print_message "Testing backup database integrity..." "$YELLOW"
    if sqlite3 "$BACKUP_SUBDIR/db.sqlite3" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        print_message "✓ Backup database integrity check PASSED" "$GREEN"
    else
        print_message "⚠ Cannot verify backup database integrity" "$YELLOW"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            rm -rf "$TEMP_RESTORE_DIR"
            exit 1
        fi
    fi
fi

# Create safety backup of current data
SAFETY_BACKUP_DIR="/root/vw-safety-backups"
mkdir -p "$SAFETY_BACKUP_DIR"
SAFETY_BACKUP="$SAFETY_BACKUP_DIR/pre_restore_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

print_message "Creating safety backup of current data..." "$YELLOW"
print_message "Safety backup location: $SAFETY_BACKUP" "$BLUE"

# Stop container before safety backup
cd "$VAULTWARDEN_DIR"
$DOCKER_COMPOSE stop
sleep 3

# Create safety backup
if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR)" ]; then
    tar -czf "$SAFETY_BACKUP" -C "$DATA_DIR" . 2>/dev/null
    chmod 600 "$SAFETY_BACKUP"
    print_message "✓ Safety backup created successfully" "$GREEN"
else
    print_message "No existing data to backup" "$YELLOW"
fi

# Clear current data directory
print_message "Removing current data..." "$YELLOW"
if [ -d "$DATA_DIR" ]; then
    # Keep the directory but remove contents
    rm -rf "$DATA_DIR"/*
    rm -rf "$DATA_DIR"/.[!.]*  2>/dev/null || true
else
    # Create data directory if it doesn't exist
    mkdir -p "$DATA_DIR"
fi

# Restore database
print_message "Restoring database..." "$YELLOW"
cp "$BACKUP_SUBDIR/db.sqlite3" "$DATA_DIR/"
[ -f "$BACKUP_SUBDIR/db.sqlite3-wal" ] && cp "$BACKUP_SUBDIR/db.sqlite3-wal" "$DATA_DIR/"
[ -f "$BACKUP_SUBDIR/db.sqlite3-shm" ] && cp "$BACKUP_SUBDIR/db.sqlite3-shm" "$DATA_DIR/"
print_message "✓ Database restored" "$GREEN"

# Restore RSA keys
print_message "Restoring RSA keys..." "$YELLOW"
for key_file in rsa_key.pem rsa_key.pub.pem rsa_key.der; do
    if [ -f "$BACKUP_SUBDIR/$key_file" ]; then
        cp "$BACKUP_SUBDIR/$key_file" "$DATA_DIR/"
        print_message "✓ $key_file restored" "$GREEN"
    fi
done

# Restore attachments
if [ -d "$BACKUP_SUBDIR/attachments" ]; then
    print_message "Restoring attachments..." "$YELLOW"
    cp -r "$BACKUP_SUBDIR/attachments" "$DATA_DIR/"
    ATTACHMENT_COUNT=$(find "$DATA_DIR/attachments" -type f 2>/dev/null | wc -l)
    print_message "✓ Restored $ATTACHMENT_COUNT attachment files" "$GREEN"
fi

# Restore sends
if [ -d "$BACKUP_SUBDIR/sends" ]; then
    print_message "Restoring sends..." "$YELLOW"
    cp -r "$BACKUP_SUBDIR/sends" "$DATA_DIR/"
    SENDS_COUNT=$(find "$DATA_DIR/sends" -type f 2>/dev/null | wc -l)
    print_message "✓ Restored $SENDS_COUNT send files" "$GREEN"
fi

# Restore config.json
if [ -f "$BACKUP_SUBDIR/config.json" ]; then
    print_message "Restoring config.json..." "$YELLOW"
    cp "$BACKUP_SUBDIR/config.json" "$DATA_DIR/"
    print_message "✓ Config restored" "$GREEN"
fi

# Restore icon_cache (optional)
if [ -d "$BACKUP_SUBDIR/icon_cache" ]; then
    print_message "Restoring icon cache..." "$YELLOW"
    cp -r "$BACKUP_SUBDIR/icon_cache" "$DATA_DIR/"
    ICON_COUNT=$(find "$DATA_DIR/icon_cache" -type f 2>/dev/null | wc -l)
    print_message "✓ Restored $ICON_COUNT icon files" "$GREEN"
fi

# Fix permissions
print_message "Setting correct permissions..." "$YELLOW"
# Vaultwarden in Docker typically runs as UID 1000
chown -R 1000:1000 "$DATA_DIR"
chmod 700 "$DATA_DIR"
[ -f "$DATA_DIR/db.sqlite3" ] && chmod 600 "$DATA_DIR/db.sqlite3"
[ -f "$DATA_DIR/rsa_key.pem" ] && chmod 400 "$DATA_DIR/rsa_key.pem"
[ -f "$DATA_DIR/config.json" ] && chmod 600 "$DATA_DIR/config.json"
print_message "✓ Permissions set" "$GREEN"

# Clean up temporary files
rm -rf "$TEMP_RESTORE_DIR"

# Start Vaultwarden container
print_message "Starting Vaultwarden container..." "$YELLOW"
cd "$VAULTWARDEN_DIR"
$DOCKER_COMPOSE up -d

# Wait for container to be ready
print_message "Waiting for Vaultwarden to be ready..." "$YELLOW"
sleep 5

# Check container status
MAX_ATTEMPTS=10
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if docker ps | grep -q "$CONTAINER_NAME"; then
        # Check if container is healthy (if health check is configured)
        CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
        if [ "$CONTAINER_STATUS" = "running" ]; then
            print_message "✓ Container is running" "$GREEN"
            
            # Try to check if the service is responding (adjust port as needed)
            if command -v curl &> /dev/null; then
                if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null | grep -q "200\|302"; then
                    print_message "✓ Vaultwarden service is responding" "$GREEN"
                fi
            fi
            break
        fi
    fi
    
    print_message "Waiting for container to start... (Attempt $ATTEMPT/$MAX_ATTEMPTS)" "$YELLOW"
    sleep 2
    ((ATTEMPT++))
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    print_message "⚠ Container may not have started properly!" "$RED"
    print_message "Check logs with: docker logs $CONTAINER_NAME" "$YELLOW"
fi

# Final summary
echo
print_message "═══════════════════════════════════════════════════════════" "$GREEN"
print_message "              ✅ RESTORE COMPLETED SUCCESSFULLY!             " "$GREEN"
print_message "═══════════════════════════════════════════════════════════" "$GREEN"
echo
print_message "📋 Summary:" "$CYAN"
print_message "  • Backup restored from: $(basename $BACKUP_FILE)" "$BLUE"
print_message "  • Safety backup saved at: $SAFETY_BACKUP" "$BLUE"
print_message "  • Container status: $(docker ps | grep -q $CONTAINER_NAME && echo 'RUNNING' || echo 'CHECK REQUIRED')" "$BLUE"
echo
print_message "⚠️  IMPORTANT NEXT STEPS:" "$YELLOW"
print_message "  1. Test login to your Vaultwarden immediately" "$YELLOW"
print_message "  2. Verify your passwords and 2FA codes are accessible" "$YELLOW"
print_message "  3. Check that all expected accounts are present" "$YELLOW"
print_message "  4. Keep the safety backup until you confirm everything works!" "$YELLOW"
echo
print_message "🔧 Useful commands:" "$CYAN"
print_message "  • Check logs: docker logs $CONTAINER_NAME" "$BLUE"
print_message "  • Container status: docker ps | grep $CONTAINER_NAME" "$BLUE"
print_message "  • Rollback if needed: ./vaultwarden-restore.sh $SAFETY_BACKUP" "$BLUE"
echo

# Show how to rollback if needed
cat > "$SAFETY_BACKUP_DIR/rollback_instructions.txt" << EOF
ROLLBACK INSTRUCTIONS
====================
If the restore didn't work as expected, you can rollback using:

./vaultwarden-restore.sh $SAFETY_BACKUP

This safety backup was created on: $(date)
Original restore was from: $BACKUP_FILE
EOF

print_message "Rollback instructions saved to: $SAFETY_BACKUP_DIR/rollback_instructions.txt" "$GREEN"
