#!/bin/bash

# FoodShare Build Script
# Builds both iOS and Android from single Swift codebase

set -e

echo "🍎 FoodShare Build Script"
echo "========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Skip is installed
if ! command -v skip &> /dev/null; then
    echo -e "${RED}❌ Skip not found${NC}"
    echo "Install with: brew install skiptools/skip/skip"
    exit 1
fi

echo -e "${GREEN}✓ Skip found${NC}"

# Parse arguments
BUILD_IOS=false
BUILD_ANDROID=false
RUN_TESTS=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --ios)
            BUILD_IOS=true
            shift
            ;;
        --android)
            BUILD_ANDROID=true
            shift
            ;;
        --all)
            BUILD_IOS=true
            BUILD_ANDROID=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./build.sh [--ios] [--android] [--all] [--test] [--clean]"
            exit 1
            ;;
    esac
done

# Default to building both if no option specified
if [ "$BUILD_IOS" = false ] && [ "$BUILD_ANDROID" = false ]; then
    BUILD_IOS=true
    BUILD_ANDROID=true
fi

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo ""
    echo "🧹 Cleaning build artifacts..."
    rm -rf .build
    rm -rf Darwin/build
    rm -rf Android/app/build
    echo -e "${GREEN}✓ Clean complete${NC}"
fi

# Run tests
if [ "$RUN_TESTS" = true ]; then
    echo ""
    echo "🧪 Running tests..."
    swift test
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Tests passed${NC}"
    else
        echo -e "${RED}❌ Tests failed${NC}"
        exit 1
    fi
fi

# Build Swift (transpiles to Kotlin)
echo ""
echo "🔨 Building Swift codebase..."
swift build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Swift build complete${NC}"
else
    echo -e "${RED}❌ Swift build failed${NC}"
    exit 1
fi

# Build iOS
if [ "$BUILD_IOS" = true ]; then
    echo ""
    echo "📱 Building iOS app..."
    xcodebuild -workspace Project.xcworkspace \
        -scheme FoodShare \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        build
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ iOS build complete${NC}"
    else
        echo -e "${RED}❌ iOS build failed${NC}"
        exit 1
    fi
fi

# Build Android
if [ "$BUILD_ANDROID" = true ]; then
    echo ""
    echo "🤖 Building Android app..."
    cd Android
    ./gradlew assembleDebug
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Android build complete${NC}"
        echo "APK: Android/app/build/outputs/apk/debug/app-debug.apk"
    else
        echo -e "${RED}❌ Android build failed${NC}"
        exit 1
    fi
    cd ..
fi

# Summary
echo ""
echo "========================="
echo -e "${GREEN}✅ Build complete!${NC}"
echo ""

if [ "$BUILD_IOS" = true ]; then
    echo "iOS: Run in Xcode or use 'open Project.xcworkspace'"
fi

if [ "$BUILD_ANDROID" = true ]; then
    echo "Android: Install with 'adb install Android/app/build/outputs/apk/debug/app-debug.apk'"
fi

echo ""
