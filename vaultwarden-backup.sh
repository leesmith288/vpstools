#!/bin/bash

# ============================================
# Vaultwarden Backup Script - Fixed Version
# ============================================
# Save this as: /root/scripts/vaultwarden-backup.sh
# Make executable: chmod +x /root/scripts/vaultwarden-backup.sh
# Usage: ./vaultwarden-backup.sh [--no-stop]
# ============================================

# Configuration
DATA_DIR="/vw-data"  # Your actual data directory from docker-compose
VAULTWARDEN_DIR="/root/vaultwarden"  # Where your docker-compose.yml is located
BACKUP_DIR="/root/vw-backups"
CONTAINER_NAME="vaultwarden"
KEEP_DAYS=30  # Keep backups for 30 days
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Check for --no-stop flag (backup without stopping container)
STOP_CONTAINER=true
if [ "$1" == "--no-stop" ]; then
    STOP_CONTAINER=false
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}[$(date '+%Y-%m-%d %H:%M:%S')] ${1}${NC}"
}

# Detect docker compose command (new vs old version)
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

# Check if sqlite3 is installed
HAS_SQLITE3=false
if command -v sqlite3 &> /dev/null; then
    HAS_SQLITE3=true
    print_message "SQLite3 found - will use for safe backup" "$GREEN"
else
    print_message "SQLite3 not installed - will use file copy method" "$YELLOW"
    print_message "To install: apt-get install sqlite3" "$YELLOW"
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    exit 1
fi

# Check if data directory exists
if [ ! -d "$DATA_DIR" ]; then
    print_message "ERROR: Data directory not found: $DATA_DIR" "$RED"
    exit 1
fi

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    print_message "Created backup directory: $BACKUP_DIR" "$GREEN"
fi

# Create a subdirectory for this backup
BACKUP_SUBDIR="$BACKUP_DIR/backup_$TIMESTAMP"
mkdir -p "$BACKUP_SUBDIR"

print_message "========================================" "$BLUE"
print_message "Starting Vaultwarden backup..." "$GREEN"
print_message "Mode: $([ "$STOP_CONTAINER" = true ] && echo 'WITH container stop (safer)' || echo 'WITHOUT stopping (zero downtime)')" "$BLUE"
print_message "========================================" "$BLUE"

# Step 1: Optionally stop the container
if [ "$STOP_CONTAINER" = true ]; then
    print_message "Stopping Vaultwarden container for consistent backup..." "$YELLOW"
    cd "$VAULTWARDEN_DIR"
    $DOCKER_COMPOSE stop
    sleep 3
fi

# Step 2: Backup the SQLite database
if [ -f "$DATA_DIR/db.sqlite3" ]; then
    print_message "Backing up SQLite database..." "$YELLOW"
    
    if [ "$STOP_CONTAINER" = true ] || [ "$HAS_SQLITE3" = false ]; then
        # Container is stopped OR sqlite3 not available, use simple copy
        cp "$DATA_DIR/db.sqlite3" "$BACKUP_SUBDIR/"
        # Also copy WAL and SHM files if they exist
        [ -f "$DATA_DIR/db.sqlite3-wal" ] && cp "$DATA_DIR/db.sqlite3-wal" "$BACKUP_SUBDIR/"
        [ -f "$DATA_DIR/db.sqlite3-shm" ] && cp "$DATA_DIR/db.sqlite3-shm" "$BACKUP_SUBDIR/"
    else
        # Container is running AND sqlite3 available, use SQLite backup command
        sqlite3 "$DATA_DIR/db.sqlite3" ".backup '$BACKUP_SUBDIR/db.sqlite3'"
        # Checkpoint the WAL
        sqlite3 "$DATA_DIR/db.sqlite3" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
    fi
    
    print_message "Database backup completed" "$GREEN"
else
    print_message "ERROR: Database file not found at $DATA_DIR/db.sqlite3!" "$RED"
    [ "$STOP_CONTAINER" = true ] && cd "$VAULTWARDEN_DIR" && $DOCKER_COMPOSE start
    exit 1
fi

# Step 3: Backup RSA keys (CRITICAL - without these, data cannot be decrypted!)
print_message "Backing up RSA keys..." "$YELLOW"
RSA_KEY_COUNT=0
if [ -f "$DATA_DIR/rsa_key.pem" ]; then
    cp "$DATA_DIR/rsa_key.pem" "$BACKUP_SUBDIR/"
    print_message "✓ rsa_key.pem backed up" "$GREEN"
    ((RSA_KEY_COUNT++))
fi

if [ -f "$DATA_DIR/rsa_key.pub.pem" ]; then
    cp "$DATA_DIR/rsa_key.pub.pem" "$BACKUP_SUBDIR/"
    print_message "✓ rsa_key.pub.pem backed up" "$GREEN"
    ((RSA_KEY_COUNT++))
fi

if [ -f "$DATA_DIR/rsa_key.der" ]; then
    cp "$DATA_DIR/rsa_key.der" "$BACKUP_SUBDIR/"
    print_message "✓ rsa_key.der backed up" "$GREEN"
    ((RSA_KEY_COUNT++))
fi

if [ $RSA_KEY_COUNT -eq 0 ]; then
    print_message "⚠ WARNING: No RSA keys found! These are generated on first use." "$YELLOW"
    print_message "  Make sure to backup again after adding your first password!" "$YELLOW"
fi

# Step 4: Backup attachments folder if it exists and has content
if [ -d "$DATA_DIR/attachments" ] && [ "$(ls -A $DATA_DIR/attachments 2>/dev/null)" ]; then
    print_message "Backing up attachments..." "$YELLOW"
    cp -r "$DATA_DIR/attachments" "$BACKUP_SUBDIR/"
    ATTACHMENT_COUNT=$(find "$DATA_DIR/attachments" -type f 2>/dev/null | wc -l)
    print_message "✓ Backed up $ATTACHMENT_COUNT attachment files" "$GREEN"
else
    print_message "No attachments to backup" "$BLUE"
fi

# Step 5: Backup sends folder if it exists
if [ -d "$DATA_DIR/sends" ] && [ "$(ls -A $DATA_DIR/sends 2>/dev/null)" ]; then
    print_message "Backing up sends..." "$YELLOW"
    cp -r "$DATA_DIR/sends" "$BACKUP_SUBDIR/"
    SENDS_COUNT=$(find "$DATA_DIR/sends" -type f 2>/dev/null | wc -l)
    print_message "✓ Backed up $SENDS_COUNT send files" "$GREEN"
else
    print_message "No sends to backup" "$BLUE"
fi

# Step 6: Backup config.json if it exists (contains admin panel settings)
if [ -f "$DATA_DIR/config.json" ]; then
    print_message "Backing up config.json..." "$YELLOW"
    cp "$DATA_DIR/config.json" "$BACKUP_SUBDIR/"
    print_message "✓ Config.json backed up" "$GREEN"
else
    print_message "No config.json found (using environment variables only)" "$BLUE"
fi

# Step 7: Backup icon_cache (optional, can be regenerated)
if [ -d "$DATA_DIR/icon_cache" ] && [ "$(ls -A $DATA_DIR/icon_cache 2>/dev/null)" ]; then
    # For automated backups, skip icon cache by default
    if [ -t 0 ]; then  # Check if running interactively
        read -t 5 -p "Backup icon cache? (y/N, auto-skip in 5s): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message "Backing up icon cache..." "$YELLOW"
            cp -r "$DATA_DIR/icon_cache" "$BACKUP_SUBDIR/"
            ICON_COUNT=$(find "$DATA_DIR/icon_cache" -type f 2>/dev/null | wc -l)
            print_message "✓ Backed up $ICON_COUNT icon files" "$GREEN"
        else
            print_message "Skipping icon cache backup" "$BLUE"
        fi
    else
        print_message "Skipping icon cache (automated backup)" "$BLUE"
    fi
fi

# Step 8: Backup docker-compose.yml and .env file
print_message "Backing up Docker configuration..." "$YELLOW"
if [ -f "$VAULTWARDEN_DIR/docker-compose.yml" ]; then
    cp "$VAULTWARDEN_DIR/docker-compose.yml" "$BACKUP_SUBDIR/"
    print_message "✓ docker-compose.yml backed up" "$GREEN"
fi
if [ -f "$VAULTWARDEN_DIR/docker-compose.yaml" ]; then
    cp "$VAULTWARDEN_DIR/docker-compose.yaml" "$BACKUP_SUBDIR/"
    print_message "✓ docker-compose.yaml backed up" "$GREEN"
fi
if [ -f "$VAULTWARDEN_DIR/.env" ]; then
    cp "$VAULTWARDEN_DIR/.env" "$BACKUP_SUBDIR/"
    print_message "✓ .env file backed up" "$GREEN"
fi

# Step 9: Create backup info file
cat > "$BACKUP_SUBDIR/backup_info.txt" << EOF
Vaultwarden Backup Information
==============================
Backup Date: $(date)
Backup Method: $([ "$STOP_CONTAINER" = true ] && echo 'With container stop' || echo 'Without stopping (live backup)')
SQLite3 Available: $HAS_SQLITE3
Data Directory: $DATA_DIR
Container Name: $CONTAINER_NAME
Database Size: $(du -h "$BACKUP_SUBDIR/db.sqlite3" 2>/dev/null | cut -f1)
Docker Compose Command: $DOCKER_COMPOSE

Files Backed Up:
$(ls -la "$BACKUP_SUBDIR/" | tail -n +2)
EOF

# Step 10: Restart container if it was stopped
if [ "$STOP_CONTAINER" = true ]; then
    print_message "Starting Vaultwarden container..." "$YELLOW"
    cd "$VAULTWARDEN_DIR"
    $DOCKER_COMPOSE start
    sleep 5
    
    # Verify container is running
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_message "✓ Vaultwarden container is running" "$GREEN"
    else
        print_message "⚠ WARNING: Container may not be running properly!" "$RED"
        print_message "  Try: cd $VAULTWARDEN_DIR && $DOCKER_COMPOSE up -d" "$YELLOW"
    fi
fi

# Step 11: Create compressed archive
print_message "Creating compressed archive..." "$YELLOW"
cd "$BACKUP_DIR"
tar -czf "vaultwarden_backup_${TIMESTAMP}.tar.gz" "backup_$TIMESTAMP"
rm -rf "$BACKUP_SUBDIR"

# Step 12: Set secure permissions on backup
chmod 600 "$BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz"

# Step 13: Clean up old backups
print_message "Cleaning up backups older than $KEEP_DAYS days..." "$YELLOW"
find "$BACKUP_DIR" -name "vaultwarden_backup_*.tar.gz" -type f -mtime +$KEEP_DAYS -delete

# Step 14: Test database integrity (if sqlite3 is available)
if [ "$HAS_SQLITE3" = true ]; then
    print_message "Testing backup integrity..." "$YELLOW"
    TEMP_TEST="/tmp/test_backup_$$"
    mkdir -p "$TEMP_TEST"
    tar -xzf "$BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz" -C "$TEMP_TEST" --strip-components=1
    
    if sqlite3 "$TEMP_TEST/db.sqlite3" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        print_message "✓ Database integrity check PASSED" "$GREEN"
    else
        print_message "⚠ Cannot verify integrity (but backup should be fine)" "$YELLOW"
    fi
    rm -rf "$TEMP_TEST"
else
    print_message "Skipping integrity check (sqlite3 not installed)" "$BLUE"
fi

# Step 15: Generate summary
echo
print_message "========================================" "$BLUE"
print_message "BACKUP COMPLETED SUCCESSFULLY!" "$GREEN"
print_message "========================================" "$BLUE"
BACKUP_SIZE=$(du -h "$BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz" | cut -f1)
print_message "Backup file: $BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz" "$GREEN"
print_message "Backup size: $BACKUP_SIZE" "$GREEN"
print_message "Downtime: $([ "$STOP_CONTAINER" = true ] && echo '~10-30 seconds' || echo 'Zero')" "$BLUE"

# List recent backups
echo
print_message "Recent backups (newest first):" "$BLUE"
ls -lht "$BACKUP_DIR"/vaultwarden_backup_*.tar.gz 2>/dev/null | head -5

echo
print_message "✓ You can now download: $BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz" "$GREEN"
print_message "To restore, use: ./vaultwarden-restore.sh $BACKUP_DIR/vaultwarden_backup_${TIMESTAMP}.tar.gz" "$BLUE"

# Optional: Install sqlite3 suggestion
if [ "$HAS_SQLITE3" = false ]; then
    echo
    print_message "TIP: Install sqlite3 for better backup integrity checking:" "$YELLOW"
    print_message "     apt-get update && apt-get install -y sqlite3" "$YELLOW"
fi
