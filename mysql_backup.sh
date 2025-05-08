#!/bin/bash

# === LOAD .env VARIABLES ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "Error: .env file not found in script directory."
    exit 1
fi

# === VERIFY REQUIRED VARIABLES ===
if [[ -z "$APP_KEY" || -z "$APP_SECRET" || -z "$REFRESH_TOKEN" || -z "$DB_NAME" ]]; then
    echo "Error: Missing APP_KEY, APP_SECRET, REFRESH_TOKEN, or DB_NAME in .env file."
    exit 1
fi


# === CONFIGURATION ===
BACKUP_DIR="/tmp/mysql_backups"
ZIP_NAME="backup_$(date +%Y%m%d_%H%M%S).zip"
DROPBOX_UPLOAD_PATH="/backups/$ZIP_NAME"  # Dropbox folder path

# === CREATE BACKUP DIRECTORY ===
mkdir -p "$BACKUP_DIR"

# === DUMP DATABASE ===
DUMP_FILE="$BACKUP_DIR/${DB_NAME}_backup.sql"
mysqldump --no-tablespaces "$DB_NAME" > "$DUMP_FILE"

# === ZIP THE BACKUP ===
cd "$BACKUP_DIR" || exit
zip "$ZIP_NAME" "${DB_NAME}_backup.sql"

# === GET FRESH ACCESS TOKEN ===
ACCESS_TOKEN=$(curl -s -X POST https://api.dropboxapi.com/oauth2/token \
  -u "$APP_KEY:$APP_SECRET" \
  -d grant_type=refresh_token \
  -d refresh_token="$REFRESH_TOKEN" | jq -r '.access_token')

if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
    echo "Error: Failed to fetch access token from Dropbox."
    exit 1
fi



# === UPLOAD TO DROPBOX ===
curl -X POST https://content.dropboxapi.com/2/files/upload \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Dropbox-API-Arg: {\"path\": \"$DROPBOX_UPLOAD_PATH\", \"mode\": \"add\", \"autorename\": true, \"mute\": false}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary @"$ZIP_NAME" \
    && echo "Backup uploaded to Dropbox: $DROPBOX_UPLOAD_PATH" \
    || echo "Error uploading backup to Dropbox."

# === CLEAN UP ===
rm -f "${DB_NAME}_backup.sql" "$ZIP_NAME"