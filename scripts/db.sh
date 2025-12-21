#!/bin/bash
set -e

echo "======================================"
echo "Clientats Database Management (SQLite)"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Parse command
case "$1" in
    reset)
        echo ""
        echo "⚠️  This will DELETE all data and reset the database!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo "Dropping database..."
            mix ecto.drop
            echo "Creating database..."
            mix ecto.create
            echo "Running migrations..."
            mix ecto.migrate
            echo "✅ Database reset complete"
        else
            echo "Cancelled"
        fi
        ;;

    migrate)
        echo ""
        echo "Running database migrations..."
        mix ecto.migrate
        echo "✅ Migrations complete"
        ;;

    rollback)
        echo ""
        echo "Rolling back last migration..."
        mix ecto.rollback
        echo "✅ Rollback complete"
        ;;

    status)
        echo ""
        echo "Database path:"
        mix run -e 'IO.puts(Clientats.Repo.config()[:database])'
        ;;

    *)
        echo ""
        echo "Usage: ./scripts/db.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  reset      Drop and recreate database (deletes all data!)"
        echo "  migrate    Run pending database migrations"
        echo "  rollback   Rollback the last migration"
        echo "  status     Show database path"
        echo ""
        echo "Examples:"
        echo "  ./scripts/db.sh migrate"
        echo "  ./scripts/db.sh status"
        echo ""
        exit 1
        ;;
esac

echo ""