#!/bin/bash
#
# Interactive release script for ucharm
# Creates a new version tag and pushes it to trigger the release workflow
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get current version from git tags
get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"
}

# Parse version into components
parse_version() {
    local version=$1
    IFS='.' read -r MAJOR MINOR PATCH <<< "$version"
}

# Bump version based on type
bump_version() {
    local version=$1
    local bump_type=$2

    parse_version "$version"

    case $bump_type in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
    esac

    echo "$MAJOR.$MINOR.$PATCH"
}

# Main script
echo -e "${CYAN}"
echo "  μcharm Release Script"
echo "  ─────────────────────"
echo -e "${NC}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}Error: You have uncommitted changes.${NC}"
    echo "Please commit or stash them before releasing."
    exit 1
fi

# Get current version
CURRENT_VERSION=$(get_current_version)
echo -e "Current version: ${GREEN}v$CURRENT_VERSION${NC}"
echo ""

# Calculate next versions
NEXT_PATCH=$(bump_version "$CURRENT_VERSION" "patch")
NEXT_MINOR=$(bump_version "$CURRENT_VERSION" "minor")
NEXT_MAJOR=$(bump_version "$CURRENT_VERSION" "major")

# Prompt for version bump type
echo "Select version bump:"
echo -e "  ${CYAN}1)${NC} Patch  → v$NEXT_PATCH  (bug fixes)"
echo -e "  ${CYAN}2)${NC} Minor  → v$NEXT_MINOR  (new features)"
echo -e "  ${CYAN}3)${NC} Major  → v$NEXT_MAJOR  (breaking changes)"
echo -e "  ${CYAN}4)${NC} Custom version"
echo -e "  ${CYAN}q)${NC} Quit"
echo ""
read -p "Choice [1-4, q]: " choice

case $choice in
    1)
        NEW_VERSION=$NEXT_PATCH
        ;;
    2)
        NEW_VERSION=$NEXT_MINOR
        ;;
    3)
        NEW_VERSION=$NEXT_MAJOR
        ;;
    4)
        read -p "Enter custom version (without 'v' prefix): " NEW_VERSION
        ;;
    q|Q)
        echo "Aborted."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice.${NC}"
        exit 1
        ;;
esac

# Confirm
echo ""
echo -e "Will create release: ${GREEN}v$NEW_VERSION${NC}"
read -p "Continue? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create and push tag
echo ""
echo -e "${CYAN}Creating tag v$NEW_VERSION...${NC}"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo -e "${CYAN}Pushing tag to origin...${NC}"
git push origin "v$NEW_VERSION"

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "The release workflow will now:"
echo "  1. Build binaries for all platforms"
echo "  2. Generate AI-powered release notes"
echo "  3. Create GitHub release with assets"
echo "  4. Update Homebrew formula (if configured)"
echo ""
echo -e "Watch progress at: ${CYAN}https://github.com/ucharmdev/ucharm/actions${NC}"
