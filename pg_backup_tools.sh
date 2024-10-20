#!/bin/bash

# Default Configuration
DAYS_TO_KEEP=90
PORT="5432"

# Ensure the Google Cloud SDK is installed and configured
if ! command -v gsutil &> /dev/null; then
    echo "Google Cloud SDK is not installed. Please install it and configure it before running this script."
    exit 1
fi

# Ensure the Postgres Dump is installed and configured
if ! command -v pg_dump &> /dev/null; then
    echo "Postgres Dump is not installed. Please install it and configure it before running this script."
    exit 1
fi

# Function to perform backup
perform_backup() {
    local db_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local bucket_name="$6"

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SUBDIR="${host}/${db_name}"
    mkdir -p "/tmp/$SUBDIR"

    BACKUP_FILE="/tmp/${SUBDIR}/${TIMESTAMP}.sql.gz"

    echo "Starting backup of $db_name on $host..."
    PGPASSWORD="$password" pg_dump -h "$host" -p "$port" -U "$user" "$db_name" | gzip > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "Backup of $db_name on $host completed successfully. Uploading to Google Cloud Storage..."
        gsutil cp "$BACKUP_FILE" "gs://$bucket_name/$SUBDIR/"
        if [ $? -eq 0 ]; then
            echo "Backup of $db_name on $host uploaded successfully."
            rm "$BACKUP_FILE"
        else
            echo "Failed to upload backup of $db_name on $host to Google Cloud Storage."
        fi
    else
        echo "Backup of $db_name on $host failed."
    fi
}

# Function to perform restore
perform_restore() {
    local db_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local bucket_name="$6"
    local backup_file="$7"

    SUBDIR=$(dirname $backup_file)
    mkdir -p "/tmp/$SUBDIR"

    echo "Downloading backup file from Google Cloud Storage..."
    gsutil cp "gs://$bucket_name/$backup_file" "/tmp/$backup_file"

    if [ $? -eq 0 ]; then
        echo "Starting restore of $db_name on $host..."
        gunzip < "/tmp/$backup_file" | PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" "$db_name"
        if [ $? -eq 0 ]; then
            echo "Restore of $db_name on $host completed successfully."
            rm "/tmp/$backup_file"
        else
            echo "Restore of $db_name on $host failed."
        fi
    else
        echo "Failed to download backup file from Google Cloud Storage."
    fi
}

# Function to list available backups
list_backups() {
    local host="$1"
    local db_name="$2"
    local bucket_name="$3"
    echo "Available backups for $db_name on $host in Google Cloud Storage:"
    gsutil ls "gs://$bucket_name/${host}/${db_name}/*"
}

# Function to delete old backups
delete_old_backups() {
    local host="$1"
    local db_name="$2"
    local bucket_name="$3"
    echo "Deleting backups older than $DAYS_TO_KEEP days for $db_name on $host..."
    gsutil ls "gs://$bucket_name/${host}/${db_name}/*" | while read -r file; do
        timestamp=$(echo "$file" | grep -oP '\d{8}_\d{6}')
        if [ ! -z "$timestamp" ]; then
            file_date=$(date -d "${timestamp:0:8}" +%s)
            current_date=$(date +%s)
            age_in_days=$(( (current_date - file_date) / 86400 ))
            if [ $age_in_days -gt $DAYS_TO_KEEP ]; then
                echo "Deleting old backup: $file"
                gsutil rm "$file"
            fi
        fi
    done
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 -c <command> [options]"
    echo ""
    echo "Commands:"
    echo "  backup    Perform backup for one or more databases"
    echo "  restore   Restore a specific database from a backup file"
    echo "  list      List available backups for a database"
    echo "  clean     Delete old backups for one or more databases"
    echo ""
    echo "Options:"
    echo "  -b <name>         GCS bucket name"
    echo "  -d <name>         Database name"
    echo "  -h <hostname>     PostgreSQL host"
    echo "  -p <port>         PostgreSQL port (default: 5432)"
    echo "  -u <username>     PostgreSQL user"
    echo "  -P <password>     PostgreSQL password"
    echo "  -f <filename>     Backup file to restore from"
    echo "  -k <days>         Days to keep backups (default: $DAYS_TO_KEEP)"
    echo "  -c <command>      Command to execute (backup, restore, list, clean)"
    echo "  -?                Show this help message"
}

# Parse command-line options using getopts
while getopts "b:d:h:p:u:P:f:k:c:?" opt; do
    case $opt in
        b) BUCKET_NAME="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        h) HOST="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        u) USER="$OPTARG" ;;
        P) PASSWORD="$OPTARG" ;;
        f) BACKUP_FILE="$OPTARG" ;;
        k) DAYS_TO_KEEP="$OPTARG" ;;
        c) COMMAND="$OPTARG" ;;
        ?) show_usage; exit 0 ;;
        *) show_usage; exit 1 ;;
    esac
done

# Validate required parameters for commands
case "$COMMAND" in
    backup)
        if [ -z "$DB_NAME" ] || [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$BUCKET_NAME" ]; then
            echo "Missing required options for backup."
            echo "$DB_NAME"
            echo "$HOST"
            echo "$USER"
            echo "$PASSWORD"
            echo "$BUCKET_NAME"
            show_usage
            exit 1
        fi
        perform_backup "$DB_NAME" "$HOST" "$PORT" "$USER" "$PASSWORD" "$BUCKET_NAME"
        ;;
    restore)
        if [ -z "$DB_NAME" ] || [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$BUCKET_NAME" ] || [ -z "$BACKUP_FILE" ]; then
            echo "Missing required options for restore."
            show_usage
            exit 1
        fi
        perform_restore "$DB_NAME" "$HOST" "$PORT" "$USER" "$PASSWORD" "$BUCKET_NAME" "$BACKUP_FILE"
        ;;
    list)
        if [ -z "$HOST" ] || [ -z "$DB_NAME" ] || [ -z "$BUCKET_NAME" ]; then
            echo "Missing required options for list."
            show_usage
            exit 1
        fi
        list_backups "$HOST" "$DB_NAME" "$BUCKET_NAME"
        ;;
    clean)
        if [ -z "$HOST" ] || [ -z "$DB_NAME" ] || [ -z "$BUCKET_NAME" ]; then
            echo "Missing required options for clean."
            show_usage
            exit 1
        fi
        delete_old_backups "$HOST" "$DB_NAME" "$BUCKET_NAME"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

exit 0
