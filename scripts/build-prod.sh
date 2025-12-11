#!/bin/bash
set -e

echo "======================================"
echo "Building Clientats for Production"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Installing dependencies..."
mix deps.get --only prod

echo ""
echo "Step 2: Compiling application..."
MIX_ENV=prod mix compile

echo ""
echo "Step 3: Building assets..."
MIX_ENV=prod mix assets.deploy

echo ""
echo "Step 4: Creating production release..."
MIX_ENV=prod mix release

echo ""
echo "======================================"
echo "✅ Production build complete!"
echo "======================================"
echo ""
echo "Release location: _build/prod/rel/clientats"
echo ""
echo "To start the production server, run:"
echo "  ./scripts/start-prod.sh"
echo ""
