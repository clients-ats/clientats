#!/bin/bash
set -e

# Default PostgreSQL connection settings matching your Podman setup
export PGHOST=${PGHOST:-localhost}
export PGPORT=${PGPORT:-6433}
export PGUSER=${PGUSER:-postgres}
export PGPASSWORD=${PGPASSWORD:-postgres}

# Default database and output
DB_NAME="clientats_prod"
OUTPUT_FILE="postgres_export.json"

show_help() {
    echo "Usage: ./scripts/db-export.sh [OPTIONS]"
    echo ""
    echo "Exports data from the PostgreSQL production database to a JSON file."
    echo ""
    echo "Options:"
    echo "  -d, --database NAME    PostgreSQL database name (default: $DB_NAME)"
    echo "  -o, --output FILE      Output JSON file path (default: $OUTPUT_FILE)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Connection Environment Variables (can be overridden):"
    echo "  PGHOST      (current: $PGHOST)"
    echo "  PGPORT      (current: $PGPORT)"
    echo "  PGUSER      (current: $PGUSER)"
    echo "  PGPASSWORD  (current: ********)"
    echo ""
    echo "Example:"
    echo "  ./scripts/db-export.sh -o production_backup.json"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--database)
            DB_NAME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

echo "======================================"
echo "PostgreSQL Data Export"
echo "======================================"
echo "Target:   $PGHOST:$PGPORT ($DB_NAME)"
echo "Output:   $OUTPUT_FILE"
echo "======================================"
echo ""

# Execute the Elixir export script
elixir scripts/export_postgres.exs --database "$DB_NAME" --output "$OUTPUT_FILE"

echo ""
echo "✅ Export complete!"
