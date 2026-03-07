#!/bin/bash

# Improved dependency documentation generator with proper recommends/suggests parsing

OUTPUT_FILE="DEPENDENCIES.md"
TEMP_DIR="/tmp/apt-deps-$$"
mkdir -p "$TEMP_DIR"

# Packages from Dockerfile
PACKAGES=(
    "dbus-x11"
    "supervisor"
    "tightvncserver"
    "xfce4"
    "novnc"
    "openjdk-11-jdk"
    "wget"
    "unzip"
    "qemu-kvm"
    "elinks"
    "locales"
    "npm"
    "sudo"
)

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Function to extract field from apt-cache show output
extract_field() {
    local pkg=$1
    local field=$2
    apt-cache show "$pkg" 2>/dev/null | grep "^${field}:" | head -1 | sed "s/^${field}: //"
}

# Initialize markdown file
init_markdown() {
    cat > "$OUTPUT_FILE" << 'EOF'
# Docker Image Package Dependencies Documentation

**Generated**: 2024
**System**: Debian/Ubuntu Trixie

This document provides comprehensive dependency analysis for all packages installed in the Android-in-Docker image.

## Table of Contents

- [Overview](#overview)
- [Packages Details](#packages-details)
- [Dependency Statistics](#dependency-statistics)
- [Common Patterns](#common-patterns)

---

## Overview

The following **13 primary packages** are directly installed in the Dockerfile:

EOF

    for pkg in "${PACKAGES[@]}"; do
        echo "- \`$pkg\`" >> "$OUTPUT_FILE"
    done

    cat >> "$OUTPUT_FILE" << 'EOF'

---

## Packages Details

EOF
}

# Process individual package with proper field extraction
process_package() {
    local pkg=$1
    
    cat >> "$OUTPUT_FILE" << EOF

### $pkg

#### Package Information

EOF
    
    # Get package description
    local desc=$(extract_field "$pkg" "Description")
    echo "**Description**: $desc" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Get version
    local version=$(extract_field "$pkg" "Version")
    echo "**Version**: $version" >> "$OUTPUT_FILE"
    
    # Get installed size
    local size=$(extract_field "$pkg" "Installed-Size")
    if [ -n "$size" ]; then
        echo "**Installed Size**: $size KB" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
    
    # Get dependencies
    cat >> "$OUTPUT_FILE" << 'EOF'
#### Required Dependencies (Depends)

EOF
    
    local depends=$(extract_field "$pkg" "Depends")
    if [ -z "$depends" ]; then
        echo "None" >> "$OUTPUT_FILE"
    else
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "$depends" | tr ',' '\n' | sed 's/^\s*//;s/\s*$//' >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    
    # Get recommends
    cat >> "$OUTPUT_FILE" << 'EOF'
#### Recommended Packages

EOF
    
    local recommends=$(extract_field "$pkg" "Recommends")
    if [ -z "$recommends" ]; then
        echo "None" >> "$OUTPUT_FILE"
    else
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "$recommends" | tr ',' '\n' | sed 's/^\s*//;s/\s*$//' >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    
    # Get suggests
    cat >> "$OUTPUT_FILE" << 'EOF'
#### Suggested Packages

EOF
    
    local suggests=$(extract_field "$pkg" "Suggests")
    if [ -z "$suggests" ]; then
        echo "None" >> "$OUTPUT_FILE"
    else
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "$suggests" | tr ',' '\n' | sed 's/^\s*//;s/\s*$//' >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    
    # Get pre-depends if exists
    local predepends=$(extract_field "$pkg" "Pre-Depends")
    if [ -n "$predepends" ]; then
        cat >> "$OUTPUT_FILE" << 'EOF'
#### Pre-Dependencies

EOF
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "$predepends" | tr ',' '\n' | sed 's/^\s*//;s/\s*$//' >> "$OUTPUT_FILE"
        echo "\`\`\`" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    cat >> "$OUTPUT_FILE" << 'EOF'
---

EOF
}

# Main execution
main() {
    echo "📋 Improved Dependency Documentation Generator"
    echo "=============================================="
    echo ""
    
    # Check prerequisites
    if ! command -v apt-cache &> /dev/null; then
        echo "❌ Error: apt-cache not found"
        echo "   This script requires a Debian/Ubuntu system"
        exit 1
    fi
    
    # Update apt cache
    echo "🔄 Updating APT cache..."
    sudo apt-get update -qq 2>/dev/null || {
        echo "⚠️  Could not update apt cache, continuing anyway..."
    }
    
    echo "📝 Initializing markdown file..."
    init_markdown
    
    # Process packages
    local total=${#PACKAGES[@]}
    local current=0
    
    for pkg in "${PACKAGES[@]}"; do
        current=$((current + 1))
        printf "\r[%d/%d] Processing: %-30s" "$current" "$total" "$pkg"
        process_package "$pkg"
    done
    
    echo ""
    echo ""
    
    # Add statistics section
    cat >> "$OUTPUT_FILE" << 'EOF'

## Dependency Statistics

### Package Count

| Category | Count |
|----------|-------|
| Primary Packages | 13 |

### Dependency Summary

The following table provides a quick overview of which packages have recommendations and suggestions:

| Package | Has Recommends | Has Suggests |
|---------|---|---|
EOF

    for pkg in "${PACKAGES[@]}"; do
        local recommends=$(extract_field "$pkg" "Recommends")
        local suggests=$(extract_field "$pkg" "Suggests")
        local rec="❌"
        local sug="❌"
        
        [ -n "$recommends" ] && rec="✓"
        [ -n "$suggests" ] && sug="✓"
        
        echo "| $pkg | $rec | $sug |" >> "$OUTPUT_FILE"
    done

    cat >> "$OUTPUT_FILE" << 'EOF'

---

## Common Patterns

### Java Dependencies
- `openjdk-11-jdk` provides Java runtime and development tools
- Includes headless variant for server environments

### Desktop Environment (XFCE)
- `xfce4` is a lightweight desktop manager
- Includes panel, session manager, window manager, and file manager
- Recommended packages include icon themes and power management

### VNC & Display
- `tightvncserver` provides VNC server for remote display
- `novnc` provides web-based VNC access
- Both require X11 libraries

### Development Tools
- `npm` brings Node.js package management with extensive dependencies
- `wget` for downloading files
- `unzip` for archive extraction

---

## How to Use This Documentation

### For Docker Image Optimization
1. Review "Has Recommends" and "Has Suggests" columns
2. Consider removing `--no-install-recommends` flag to include recommended packages
3. Analyze if suggested packages are needed for your use case

### For Security Audits
1. Check all listed dependencies for CVEs
2. Focus on core libraries: libc6, openssl, zlib
3. Monitor Java and Node.js dependencies closely

### For License Compliance
1. Track all listed packages in your compliance matrix
2. Note packages with multiple alternatives (indicated by |)
3. Verify XFCE and related GUI components licenses

### For Space Reduction
1. Avoid suggested packages for minimal images
2. Use `--no-install-recommends` flag in apt-get
3. Consider multi-stage builds

---

## Technical Notes

1. **Dependency Extraction**: Using \`apt-cache show\` to parse package metadata
2. **Recommends vs Suggests**: 
   - Recommends: Packages that should normally be installed with this package
   - Suggests: Additional packages that may be useful
3. **Version Management**: OpenJDK version controlled via \`${OPENJDK_VERSION}\` build argument
4. **Alternative Dependencies**: Some packages have alternatives marked with \` | \`

---

*This documentation was automatically generated using improved dependency analysis script.*
EOF

    echo "✅ Documentation successfully generated!"
    echo "📊 Output file: $OUTPUT_FILE"
    echo "📏 Total lines: $(wc -l < "$OUTPUT_FILE")"
}

# Run main function
main "$@"
