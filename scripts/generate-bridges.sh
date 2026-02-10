#!/bin/bash
#
# generate-bridges.sh
# Phase 20: Developer Experience
#
# Generates Kotlin bridge stubs from Swift modules.
# This script scans FoodshareCore Swift files and generates
# corresponding Kotlin bridge templates.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SWIFT_CORE="$PROJECT_ROOT/foodshare-core/Sources/FoodshareCore"
KOTLIN_BRIDGES="$PROJECT_ROOT/app/src/main/kotlin/com/foodshare/core"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Foodshare Bridge Generator                        ║"
echo "║           Phase 20: Developer Experience                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Function to extract public structs/classes from Swift file
extract_swift_types() {
    local file=$1
    grep -E "^public (struct|class|enum)" "$file" | \
        sed -E 's/public (struct|class|enum) ([A-Za-z0-9_]+).*/\2/' || true
}

# Function to extract public functions from Swift file
extract_swift_functions() {
    local file=$1
    grep -E "^\s+public func" "$file" | \
        sed -E 's/.*public func ([A-Za-z0-9_]+)\(.*/\1/' || true
}

# Check if bridge exists
check_bridge_exists() {
    local module=$1
    local bridge_path="$KOTLIN_BRIDGES/$module"

    if [[ -d "$bridge_path" ]]; then
        return 0
    fi
    return 1
}

# List all Swift modules
list_swift_modules() {
    echo -e "${YELLOW}Swift Modules in FoodshareCore:${NC}"
    echo ""

    for dir in "$SWIFT_CORE"/*/; do
        if [[ -d "$dir" ]]; then
            module_name=$(basename "$dir")
            swift_files=$(find "$dir" -name "*.swift" -type f | wc -l | tr -d ' ')

            # Check for corresponding Kotlin bridge
            bridge_exists="❌"
            case "$module_name" in
                Validation) [[ -f "$KOTLIN_BRIDGES/validation/ValidationBridge.kt" ]] && bridge_exists="✅" ;;
                Recommendations) [[ -f "$KOTLIN_BRIDGES/recommendations/MLRecommendationBridge.kt" ]] && bridge_exists="✅" ;;
                Sync) [[ -f "$KOTLIN_BRIDGES/sync/DeltaSyncBridge.kt" ]] && bridge_exists="✅" ;;
                Media) [[ -f "$KOTLIN_BRIDGES/media/ImagePipelineBridge.kt" ]] && bridge_exists="✅" ;;
                Search) [[ -f "$KOTLIN_BRIDGES/search/SearchEngineBridge.kt" ]] && bridge_exists="✅" ;;
                Analytics) [[ -f "$KOTLIN_BRIDGES/analytics/AdvancedAnalyticsBridge.kt" ]] && bridge_exists="✅" ;;
                Notifications) [[ -f "$KOTLIN_BRIDGES/notifications/NotificationOrchestratorBridge.kt" ]] && bridge_exists="✅" ;;
                Gamification) [[ -f "$KOTLIN_BRIDGES/gamification/GamificationEngineBridge.kt" ]] && bridge_exists="✅" ;;
                Geo) [[ -f "$KOTLIN_BRIDGES/geo/GeoIntelligenceBridge.kt" ]] && bridge_exists="✅" ;;
                Moderation) [[ -f "$KOTLIN_BRIDGES/moderation/ContentModerationBridge.kt" ]] && bridge_exists="✅" ;;
                RateLimiting) [[ -f "$KOTLIN_BRIDGES/ratelimit/RateLimitBridge.kt" ]] && bridge_exists="✅" ;;
                Performance) [[ -f "$KOTLIN_BRIDGES/performance/PerformanceMonitorBridge.kt" ]] && bridge_exists="✅" ;;
                Accessibility) [[ -f "$KOTLIN_BRIDGES/accessibility/AccessibilityEngineBridge.kt" ]] && bridge_exists="✅" ;;
                Experiments) [[ -f "$KOTLIN_BRIDGES/experiments/ExperimentBridge.kt" ]] && bridge_exists="✅" ;;
                ErrorRecovery) [[ -f "$KOTLIN_BRIDGES/errors/ErrorRecoveryBridge.kt" ]] && bridge_exists="✅" ;;
                Security) [[ -f "$KOTLIN_BRIDGES/security/SecurityBridge.kt" ]] && bridge_exists="✅" ;;
                *) bridge_exists="⚠️" ;;
            esac

            printf "  %-20s %2s Swift files  Bridge: %s\n" "$module_name" "$swift_files" "$bridge_exists"
        fi
    done
    echo ""
}

# Generate bridge report
generate_report() {
    echo -e "${YELLOW}Bridge Coverage Report:${NC}"
    echo ""

    local total_modules=0
    local bridged_modules=0

    for dir in "$SWIFT_CORE"/*/; do
        if [[ -d "$dir" ]]; then
            ((total_modules++))
            module_name=$(basename "$dir")

            # Count as bridged if any bridge file exists for this module
            case "$module_name" in
                Validation|Recommendations|Sync|Media|Search|Analytics|Notifications|Gamification|Geo|Moderation|RateLimiting|Performance|Accessibility|Experiments|ErrorRecovery|Security)
                    ((bridged_modules++))
                    ;;
            esac
        fi
    done

    local coverage=$((bridged_modules * 100 / total_modules))

    echo "  Total Swift Modules:  $total_modules"
    echo "  Bridged Modules:      $bridged_modules"
    echo "  Coverage:             $coverage%"
    echo ""

    if [[ $coverage -ge 90 ]]; then
        echo -e "  ${GREEN}✅ Excellent bridge coverage!${NC}"
    elif [[ $coverage -ge 70 ]]; then
        echo -e "  ${YELLOW}⚠️ Good coverage, some modules missing bridges${NC}"
    else
        echo -e "  ${RED}❌ Low coverage, many modules need bridges${NC}"
    fi
    echo ""
}

# Analyze a specific Swift module
analyze_module() {
    local module=$1
    local module_path="$SWIFT_CORE/$module"

    if [[ ! -d "$module_path" ]]; then
        echo -e "${RED}Module not found: $module${NC}"
        return 1
    fi

    echo -e "${YELLOW}Analyzing module: $module${NC}"
    echo ""

    for swift_file in "$module_path"/*.swift; do
        if [[ -f "$swift_file" ]]; then
            filename=$(basename "$swift_file")
            echo "  File: $filename"

            types=$(extract_swift_types "$swift_file")
            if [[ -n "$types" ]]; then
                echo "    Types:"
                while IFS= read -r type; do
                    echo "      - $type"
                done <<< "$types"
            fi

            funcs=$(extract_swift_functions "$swift_file")
            if [[ -n "$funcs" ]]; then
                echo "    Functions:"
                while IFS= read -r func; do
                    echo "      - $func()"
                done <<< "$funcs"
            fi
            echo ""
        fi
    done
}

# Main menu
case "${1:-}" in
    list)
        list_swift_modules
        ;;
    report)
        generate_report
        ;;
    analyze)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 analyze <module_name>"
            exit 1
        fi
        analyze_module "$2"
        ;;
    *)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  list      List all Swift modules and bridge status"
        echo "  report    Generate bridge coverage report"
        echo "  analyze   Analyze a specific Swift module"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 report"
        echo "  $0 analyze Gamification"
        ;;
esac
