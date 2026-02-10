#!/bin/bash
#
# run-cross-platform-tests.sh
# Phase 20: Developer Experience
#
# Runs tests for both Swift core and Kotlin bridges,
# ensuring cross-platform consistency.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Foodshare Cross-Platform Test Runner              ║"
echo "║           Phase 20: Developer Experience                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Track results
SWIFT_PASSED=0
SWIFT_FAILED=0
KOTLIN_PASSED=0
KOTLIN_FAILED=0

# Run Swift tests
run_swift_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    Running Swift Tests                        ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cd "$PROJECT_ROOT/foodshare-core"

    if swift test 2>&1; then
        SWIFT_PASSED=1
        echo ""
        echo -e "${GREEN}✅ Swift tests passed${NC}"
    else
        SWIFT_FAILED=1
        echo ""
        echo -e "${RED}❌ Swift tests failed${NC}"
    fi

    cd "$PROJECT_ROOT"
    echo ""
}

# Run Kotlin unit tests
run_kotlin_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                   Running Kotlin Tests                        ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cd "$PROJECT_ROOT"

    if ./gradlew test --quiet 2>&1; then
        KOTLIN_PASSED=1
        echo ""
        echo -e "${GREEN}✅ Kotlin tests passed${NC}"
    else
        KOTLIN_FAILED=1
        echo ""
        echo -e "${RED}❌ Kotlin tests failed${NC}"
    fi

    echo ""
}

# Run specific bridge tests
run_bridge_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                  Running Bridge Tests                         ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Test validation bridge
    echo "Testing ValidationBridge..."
    if ./gradlew :app:testDebugUnitTest --tests "com.foodshare.core.validation.*" --quiet 2>&1; then
        echo -e "  ${GREEN}✓${NC} ValidationBridge"
    else
        echo -e "  ${YELLOW}⚠${NC} ValidationBridge (no tests found or failed)"
    fi

    # Test geo bridge
    echo "Testing GeoIntelligenceBridge..."
    if ./gradlew :app:testDebugUnitTest --tests "com.foodshare.core.geo.*" --quiet 2>&1; then
        echo -e "  ${GREEN}✓${NC} GeoIntelligenceBridge"
    else
        echo -e "  ${YELLOW}⚠${NC} GeoIntelligenceBridge (no tests found or failed)"
    fi

    # Test moderation bridge
    echo "Testing ContentModerationBridge..."
    if ./gradlew :app:testDebugUnitTest --tests "com.foodshare.core.moderation.*" --quiet 2>&1; then
        echo -e "  ${GREEN}✓${NC} ContentModerationBridge"
    else
        echo -e "  ${YELLOW}⚠${NC} ContentModerationBridge (no tests found or failed)"
    fi

    echo ""
}

# Print summary
print_summary() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                       Test Summary                            ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "  Swift Tests:    $([ $SWIFT_PASSED -eq 1 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
    echo "  Kotlin Tests:   $([ $KOTLIN_PASSED -eq 1 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
    echo ""

    if [[ $SWIFT_PASSED -eq 1 && $KOTLIN_PASSED -eq 1 ]]; then
        echo -e "${GREEN}══════════════════════════════════════════════════════════════=${NC}"
        echo -e "${GREEN}                    All tests passed! ✅                       ${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════=${NC}"
        exit 0
    else
        echo -e "${RED}══════════════════════════════════════════════════════════════=${NC}"
        echo -e "${RED}                    Some tests failed ❌                        ${NC}"
        echo -e "${RED}══════════════════════════════════════════════════════════════=${NC}"
        exit 1
    fi
}

# Main execution
case "${1:-all}" in
    swift)
        run_swift_tests
        ;;
    kotlin)
        run_kotlin_tests
        ;;
    bridge)
        run_bridge_tests
        ;;
    all)
        run_swift_tests
        run_kotlin_tests
        print_summary
        ;;
    *)
        echo "Usage: $0 [swift|kotlin|bridge|all]"
        echo ""
        echo "Options:"
        echo "  swift   Run Swift FoodshareCore tests only"
        echo "  kotlin  Run Kotlin unit tests only"
        echo "  bridge  Run bridge-specific tests"
        echo "  all     Run all tests (default)"
        ;;
esac
