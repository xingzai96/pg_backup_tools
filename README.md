# PostgreSQL Backup and Restore Tool with Google Cloud Storage

This is a bash script designed to handle PostgreSQL backup management using **Google Cloud Storage (GCS)**. The tool supports backing up PostgreSQL databases, uploading backup files to GCS, restoring databases from GCS, and cleaning up old backups.

## Features

- **Backup** PostgreSQL databases and upload compressed `.sql.gz` files to Google Cloud Storage.
- **Restore** PostgreSQL databases from backups stored in GCS.
- **List** available backups in your GCS bucket for a specific database.
- **Delete** old backups in GCS based on retention policies.

## Prerequisites

Before using this tool, make sure you have:

- **Google Cloud SDK (gsutil)** installed and authenticated.
- **Postgre Client (pg_dump and psql)** tools installed.

## Installation

1. **Clone the repository**:

    ```bash
    git clone https://github.com/yourusername/pg_gcs_backup.git
    cd pg_gcs_backup
    ```

2. **Ensure Google Cloud SDK is installed**:

    ```bash
    # For Ubuntu
    sudo apt-get install google-cloud-sdk
    ```

3. **Ensure PostgreSQL utilities (pg_dump, psql) are installed**:

    ```bash
    sudo apt-get install postgresql-client
    ```

4. **Make the script executable**:

    ```bash
    chmod +x pg_gcs_backup.sh
    ```

## Usage

You can run this tool by using different commands for backup, restore, list, and cleanup. Below are examples for each.

### Backup a PostgreSQL Database

```bash
./pg_gcs_backup.sh backup -d <DB_NAME> -h <HOST> -p <PORT> -u <USER> -p <PASSWORD> -b <GCS_BUCKET>
