#!/bin/bash
set -e

echo "======================================"
echo "Clientats Database Management"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Parse command
case "$1" in
    start)
        echo ""
        echo "Starting PostgreSQL database container..."

        if podman ps --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
            echo "✅ Database is already running"
        elif podman ps -a --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
            podman start clientats-db
            echo "✅ Database started"
        else
            podman run -d --name clientats-db \
              -e POSTGRES_PASSWORD=postgres \
              -e POSTGRES_USER=postgres \
              -e POSTGRES_DB=clientats_dev \
              -p 5432:5432 \
              postgres:16-alpine
            echo "✅ Database container created and started"
        fi
        ;;

    stop)
        echo ""
        echo "Stopping database container..."
        podman stop clientats-db 2>/dev/null && echo "✅ Database stopped" || echo "Database was not running"
        ;;

    restart)
        echo ""
        echo "Restarting database container..."
        podman restart clientats-db 2>/dev/null && echo "✅ Database restarted" || {
            echo "❌ Database container not found. Creating new one..."
            $0 start
        }
        ;;

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
        if podman ps --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
            echo "✅ Database container: RUNNING"
            podman ps --filter "name=clientats-db" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        elif podman ps -a --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
            echo "⚠️  Database container: STOPPED"
        else
            echo "❌ Database container: NOT CREATED"
        fi
        ;;

    logs)
        echo ""
        echo "Showing database logs (Ctrl+C to exit)..."
        podman logs -f clientats-db
        ;;

    remove)
        echo ""
        echo "⚠️  This will remove the database container!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            podman rm -f clientats-db 2>/dev/null && echo "✅ Database container removed" || echo "Container was not found"
        else
            echo "Cancelled"
        fi
        ;;

    *)
        echo ""
        echo "Usage: ./scripts/db.sh [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  start      Start the database container"
        echo "  stop       Stop the database container"
        echo "  restart    Restart the database container"
        echo "  status     Show database container status"
        echo "  reset      Drop and recreate database (deletes all data!)"
        echo "  migrate    Run pending database migrations"
        echo "  rollback   Rollback the last migration"
        echo "  logs       Show database logs"
        echo "  remove     Remove the database container"
        echo ""
        echo "Examples:"
        echo "  ./scripts/db.sh start"
        echo "  ./scripts/db.sh status"
        echo "  ./scripts/db.sh migrate"
        echo ""
        exit 1
        ;;
esac

echo ""
