#!/bin/bash

# Metal Shader Lint Script for FluidSimApp
# Validates Metal shaders and checks for common issues

set -e

echo "🔧 Metal Shader Linting..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Find all Metal files
METAL_FILES=$(find . -name "*.metal" -type f)

if [ -z "$METAL_FILES" ]; then
    echo -e "${YELLOW}⚠️  No Metal files found${NC}"
    exit 0
fi

for metal_file in $METAL_FILES; do
    echo "📝 Checking $metal_file..."
    
    # 1. Compile check
    xcrun metal -c "$metal_file" -o /tmp/$(basename "$metal_file").air 2>/tmp/metal_errors.txt
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Compilation failed: $metal_file${NC}"
        cat /tmp/metal_errors.txt
        ERRORS=$((ERRORS + 1))
        continue
    fi
    
    # 2. Check for common issues
    
    # Unsigned/signed comparisons
    if grep -n "if.*gid.*<.*uniforms\." "$metal_file" > /dev/null; then
        echo -e "${YELLOW}⚠️  Potential signed/unsigned comparison in $metal_file${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for proper boundary checks
    if ! grep -n "gid\.x.*>=.*width.*gid\.y.*>=.*height" "$metal_file" > /dev/null; then
        echo -e "${YELLOW}⚠️  Missing boundary checks in $metal_file${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for texture usage
    if ! grep -n "texture2d" "$metal_file" > /dev/null; then
        echo -e "${YELLOW}⚠️  No texture usage found in $metal_file${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for proper kernel/fragment declarations
    if ! grep -n "kernel\|fragment\|vertex" "$metal_file" > /dev/null; then
        echo -e "${RED}❌ No kernel/fragment/vertex functions found in $metal_file${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    echo -e "${GREEN}✅ $metal_file passed basic checks${NC}"
done

# Summary
echo ""
echo "📊 Metal Lint Summary:"
echo "Files checked: $(echo "$METAL_FILES" | wc -l)"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Metal linting failed with $ERRORS errors${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Metal linting completed with $WARNINGS warnings${NC}"
    exit 0
else
    echo -e "${GREEN}✅ All Metal shaders passed linting${NC}"
    exit 0
fi