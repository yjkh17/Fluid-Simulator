#!/bin/bash

# FluidSimApp CI Post-Build Script
# Runs SwiftLint, Metal validation, and performance checks

set -e

echo "🚀 FluidSimApp CI Post-Build Starting..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. SwiftLint
echo "📝 Running SwiftLint..."
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint --reporter github-actions-logging
    if [ $? -eq 0 ]; then
        print_status "SwiftLint passed"
    else
        print_error "SwiftLint failed"
        exit 1
    fi
else
    print_warning "SwiftLint not installed, skipping..."
fi

# 2. Metal Shader Validation
echo "🔧 Validating Metal Shaders..."
METAL_FILES=$(find . -name "*.metal" -type f)
if [ -n "$METAL_FILES" ]; then
    for metal_file in $METAL_FILES; do
        echo "  Checking $metal_file..."
        xcrun metal -c "$metal_file" -o /tmp/$(basename "$metal_file").air
        if [ $? -eq 0 ]; then
            print_status "Metal shader valid: $metal_file"
        else
            print_error "Metal shader invalid: $metal_file"
            exit 1
        fi
    done
else
    print_warning "No Metal files found"
fi

# 3. Build for Release
echo "🔨 Building Release configuration..."
xcodebuild -scheme FluidSimApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15' build
if [ $? -eq 0 ]; then
    print_status "Release build successful"
else
    print_error "Release build failed"
    exit 1
fi

# 4. Run Tests
echo "🧪 Running Tests..."
xcodebuild test -scheme FluidSimApp -destination 'platform=iOS Simulator,name=iPhone 15'
if [ $? -eq 0 ]; then
    print_status "All tests passed"
else
    print_error "Tests failed"
    exit 1
fi

# 5. Performance Check (basic)
echo "⚡ Performance Check..."
BINARY_SIZE=$(find build -name "*.app" -exec du -sh {} \; | cut -f1)
print_status "App size: $BINARY_SIZE"

# 6. Archive for distribution (if on main branch)
if [ "$GITHUB_REF" = "refs/heads/main" ] || [ "$CI_BRANCH" = "main" ]; then
    echo "📦 Creating Archive..."
    xcodebuild archive -scheme FluidSimApp -configuration Release -archivePath build/FluidSimApp.xcarchive
    if [ $? -eq 0 ]; then
        print_status "Archive created successfully"
    else
        print_error "Archive failed"
        exit 1
    fi
fi

print_status "CI Post-Build completed successfully! 🎉"