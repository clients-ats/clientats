#!/bin/bash
set -e

echo "======================================"
echo "Running Clientats Test Suite"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Parse command line arguments
RUN_COVERAGE=false
RUN_FEATURE=false
RUN_PRECOMMIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage|-c)
            RUN_COVERAGE=true
            shift
            ;;
        --feature|-f)
            RUN_FEATURE=true
            shift
            ;;
        --precommit|-p)
            RUN_PRECOMMIT=true
            shift
            ;;
        --help|-h)
            echo ""
            echo "Usage: ./scripts/test.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --coverage    Run tests with coverage report"
            echo "  -f, --feature     Run browser-based feature tests (requires ChromeDriver)"
            echo "  -p, --precommit   Run full precommit checks (compile, format, test)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./scripts/test.sh              # Run all unit tests"
            echo "  ./scripts/test.sh --coverage   # Run tests with coverage"
            echo "  ./scripts/test.sh --feature    # Run only feature tests"
            echo "  ./scripts/test.sh --precommit  # Run full precommit suite"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './scripts/test.sh --help' for usage"
            exit 1
            ;;
    esac
done

if [ "$RUN_PRECOMMIT" = true ]; then
    echo ""
    echo "Running full precommit checks..."
    echo ""
    mix precommit
    exit 0
fi

echo ""
echo "Setting up test database..."
mix ecto.create --quiet 2>/dev/null || echo "Test database already exists"
mix ecto.migrate --quiet

echo ""

if [ "$RUN_FEATURE" = true ]; then
    echo "Running browser-based feature tests..."
    echo "Note: This requires ChromeDriver to be installed"
    echo ""
    mix test --only feature
elif [ "$RUN_COVERAGE" = true ]; then
    echo "Running tests with coverage report..."
    echo ""
    mix test --cover
    echo ""
    echo "📊 HTML coverage report generated in: cover/"
else
    echo "Running unit and integration tests..."
    echo ""
    mix test
fi

echo ""
echo "======================================"
echo "✅ Tests complete!"
echo "======================================"
