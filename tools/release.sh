#!/bin/bash
set -e

usage() {
    echo "Usage: $0 <major|minor|patch>"
    echo ""
    echo "Bumps the version and creates a new release tag."
    echo ""
    echo "  major  - Bump major version (1.2.3 -> 2.0.0)"
    echo "  minor  - Bump minor version (1.2.3 -> 1.3.0)"
    echo "  patch  - Bump patch version (1.2.3 -> 1.2.4)"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

BUMP_TYPE="$1"

if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
    echo "Error: Invalid bump type '$BUMP_TYPE'"
    usage
fi

# Get the latest version tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Current version: $LATEST_TAG"

# Strip the 'v' prefix and parse version
VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

# Default to 0 if parsing fails
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# Bump the appropriate version
case "$BUMP_TYPE" in
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

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "New version: $NEW_VERSION"

# Confirm before proceeding
read -p "Create and push tag $NEW_VERSION? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create and push the tag
git tag "$NEW_VERSION"
git push origin "$NEW_VERSION"

echo ""
echo "Released $NEW_VERSION"
echo "Watch the build: https://github.com/nabil-airspace-intelligence/clify/actions"
