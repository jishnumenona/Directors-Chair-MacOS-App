#!/bin/bash
#
# verify-setup.sh
# Verifies DirectorsChair-Desktop Xcode project setup
#
# Phase 9B: Xcode Configuration
# Usage: ./scripts/verify-setup.sh

set -e

echo "🔍 DirectorsChair-Desktop Setup Verification"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check workspace directory
echo "📁 Checking workspace structure..."
REQUIRED_DIRS=("DirectorsChair-Desktop" "DirectorsChairCore" "DirectorsChairViews" "DirectorsChairProduction")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} Found: $dir"
    else
        echo -e "  ${RED}✗${NC} Missing: $dir"
        exit 1
    fi
done
echo ""

# Check Package.swift files
echo "📦 Checking Swift packages..."
REQUIRED_PACKAGES=("DirectorsChairCore/Package.swift" "DirectorsChairViews/Package.swift" "DirectorsChairProduction/Package.swift")

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if [ -f "$pkg" ]; then
        echo -e "  ${GREEN}✓${NC} Found: $pkg"
    else
        echo -e "  ${RED}✗${NC} Missing: $pkg"
        exit 1
    fi
done
echo ""

# Check Xcode project
echo "🔨 Checking Xcode project..."
if [ -d "DirectorsChair-Desktop.xcodeproj" ]; then
    echo -e "  ${GREEN}✓${NC} Found: DirectorsChair-Desktop.xcodeproj"
else
    echo -e "  ${RED}✗${NC} Missing: DirectorsChair-Desktop.xcodeproj"
    exit 1
fi
echo ""

# Check main app files
echo "📄 Checking main app files..."
REQUIRED_FILES=(
    "DirectorsChair-Desktop/DirectorsChair_DesktopApp.swift"
    "DirectorsChair-Desktop/ContentView.swift"
    "DirectorsChair-Desktop/AppCoordinator.swift"
    "DirectorsChair-Desktop/ViewModels/ProjectViewModel.swift"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} Found: $(basename $file)"
    else
        echo -e "  ${RED}✗${NC} Missing: $file"
        exit 1
    fi
done
echo ""

# Check for critical imports in ContentView
echo "🔍 Checking ContentView imports..."
if grep -q "import DirectorsChairCore" "DirectorsChair-Desktop/ContentView.swift"; then
    echo -e "  ${GREEN}✓${NC} Imports DirectorsChairCore"
else
    echo -e "  ${YELLOW}⚠${NC}  Warning: Missing DirectorsChairCore import"
fi

if grep -q "import DirectorsChairViews" "DirectorsChair-Desktop/ContentView.swift"; then
    echo -e "  ${GREEN}✓${NC} Imports DirectorsChairViews"
else
    echo -e "  ${YELLOW}⚠${NC}  Warning: Missing DirectorsChairViews import"
fi

if grep -q "import DirectorsChairProduction" "DirectorsChair-Desktop/ContentView.swift"; then
    echo -e "  ${GREEN}✓${NC} Imports DirectorsChairProduction"
else
    echo -e "  ${YELLOW}⚠${NC}  Warning: Missing DirectorsChairProduction import"
fi
echo ""

# Check if Xcode can resolve packages
echo "🔧 Testing Xcode package resolution..."
if xcodebuild -list -project DirectorsChair-Desktop.xcodeproj &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Xcode project readable"

    # Check resolved packages
    RESOLVED=$(xcodebuild -list -project DirectorsChair-Desktop.xcodeproj 2>&1 | grep "Resolved source packages:" -A 10)

    if echo "$RESOLVED" | grep -q "DirectorsChairCore"; then
        echo -e "  ${GREEN}✓${NC} DirectorsChairCore resolved"
    else
        echo -e "  ${YELLOW}⚠${NC}  DirectorsChairCore not resolved"
    fi

    if echo "$RESOLVED" | grep -q "DirectorsChairViews"; then
        echo -e "  ${GREEN}✓${NC} DirectorsChairViews resolved"
    else
        echo -e "  ${YELLOW}⚠${NC}  DirectorsChairViews not resolved (needs manual Xcode setup)"
    fi

    if echo "$RESOLVED" | grep -q "DirectorsChairProduction"; then
        echo -e "  ${GREEN}✓${NC} DirectorsChairProduction resolved"
    else
        echo -e "  ${YELLOW}⚠${NC}  DirectorsChairProduction not resolved (needs manual Xcode setup)"
    fi
else
    echo -e "  ${RED}✗${NC} Cannot read Xcode project"
    exit 1
fi
echo ""

# Try to build (if requested)
if [ "$1" == "--build" ]; then
    echo "🔨 Attempting build..."
    echo "  (This may take a few minutes...)"

    if xcodebuild -scheme DirectorsChair-Desktop -configuration Debug build 2>&1 | grep -q "BUILD SUCCEEDED"; then
        echo -e "  ${GREEN}✓${NC} Build succeeded!"
    else
        echo -e "  ${RED}✗${NC} Build failed"
        echo ""
        echo "  Common issues:"
        echo "  1. Missing package dependencies (see docs/XCODE_SETUP.md)"
        echo "  2. Need to add DirectorsChairViews and DirectorsChairProduction in Xcode"
        echo "  3. Run: open DirectorsChair-Desktop.xcodeproj"
        exit 1
    fi
else
    echo "💡 To test build, run: $0 --build"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}✓ Setup verification complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open Xcode: open DirectorsChair-Desktop.xcodeproj"
echo "  2. Follow: docs/XCODE_SETUP.md to add missing packages"
echo "  3. Build: ⌘+B"
echo "  4. Run: ⌘+R"
echo ""
