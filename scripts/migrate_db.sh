#!/bin/bash
set -e

# scripts/migrate_db.sh
# Master script for migrating data from PostgreSQL to SQLite

echo "======================================"
echo "Clientats Data Migration Tool"
echo "======================================"

# Default values
DB_NAME=${1:-clientats_prod}
EXPORT_FILE="migration_export.json"

echo ""
echo "Step 1: Exporting data from PostgreSQL ($DB_NAME)..."
mix run scripts/export_postgres.exs --database "$DB_NAME" --output "$EXPORT_FILE"

echo ""
echo "Step 2: Importing data into SQLite..."
mix db.migrate_from_json --input "$EXPORT_FILE"

echo ""
echo "Step 3: Cleaning up..."
rm "$EXPORT_FILE"

echo ""
echo "======================================"
echo "✅ Data migration complete!"
echo "======================================"
