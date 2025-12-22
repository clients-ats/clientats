#!/bin/bash
set -e

echo "======================================"
echo "Starting Clientats (Production)"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Check if release exists
if [ ! -d "_build/prod/rel/clientats" ]; then
    echo "❌ Error: Production release not found!"
    echo ""
    echo "Please build the production release first:"
    echo "  ./scripts/build-prod.sh"
    echo ""
    exit 1
fi

echo ""
echo "Starting production server..."
echo "The server will start in the foreground."
echo "Press Ctrl+C to stop."
echo ""
echo "Server will be available at: http://localhost:4000"
echo "(Port can be changed with PORT environment variable)"
echo ""

# Start the release
# Note: PHX_SERVER is enabled by default in production.
# To disable, set PHX_SERVER=false before running this script.
_build/prod/rel/clientats/bin/clientats start
