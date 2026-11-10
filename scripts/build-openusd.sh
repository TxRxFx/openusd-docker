#!/usr/bin/env bash
#
# build-openusd.sh
#
# Unified OpenUSD build script for local development and CI/CD environments.
# Works with GitLab CI, GitHub Actions, and manual invocation.
#
# Usage:
#   ./scripts/build-openusd.sh --platform alma9 --version 25.05.1 --output ./artifacts
#   ./scripts/build-openusd.sh --help
#

set -Eeuo pipefail

# ============================================================================
# Configuration & Constants
# ============================================================================

# Defaults
PLATFORM=""
VERSION=""
OUTPUT_DIR=""
DRY_RUN=0
SKIP_IMAGE_BUILD=0

# Build configuration (from Dockerfiles)
PYTHON_VERSION="3.10.14"
GCCCORE_VERSION="12.3.0"
PYTHON_PREFIX="/pipeline/el9/software/Python/${PYTHON_VERSION}-GCCcore-${GCCCORE_VERSION}"
PYTHON_BIN="${PYTHON_PREFIX}/bin/python"

# USD build flags (from GitLab CI)
USD_BUILD_FLAGS=(
    "--build-variant" "release"
    "--python"
    "--usdview"
    "--no-tests"
    "--no-examples"
    "--no-tutorials"
    "--no-docs"
    "--no-python-docs"
)

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_section() {
    echo "" >&2
    echo "=================================================================================" >&2
    echo "  $*" >&2
    echo "=================================================================================" >&2
}

die() {
    log_error "$*"
    exit 1
}

show_help() {
    cat <<'EOF'
OpenUSD Build Script

Usage:
  ./scripts/build-openusd.sh --platform PLATFORM --version VERSION --output DIR [OPTIONS]

Arguments:
  --platform PLATFORM     Build platform: alma9 or rocky9 (required)
  --version VERSION       OpenUSD version tag: 25.05.1 (required)
  --output DIR            Output directory for artifacts (required)

Options:
  --skip-image-build      Use existing Docker image (skip docker build)
  --dry-run               Show what would be executed without running
  --help                  Show this help message

Examples:
  ./scripts/build-openusd.sh --platform alma9 --version 25.05.1 --output ./artifacts
  ./scripts/build-openusd.sh --platform rocky9 --version 25.05.1 --output /tmp/build
  ./scripts/build-openusd.sh --platform alma9 --version 25.05.1 --output ./artifacts --skip-image-build

Notes:
  - Requires Docker and Bash 4.0+
  - Creates platform-specific output structure
  - Generates manifest.json with build metadata
  - Artifacts are validated before reporting success
EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --skip-image-build)
            SKIP_IMAGE_BUILD=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

# ============================================================================
# Validation
# ============================================================================

log_section "Validation"

# Check required arguments
[[ -n "$PLATFORM" ]] || die "Missing required argument: --platform"
[[ -n "$VERSION" ]] || die "Missing required argument: --version"
[[ -n "$OUTPUT_DIR" ]] || die "Missing required argument: --output"

# Validate platform
case "$PLATFORM" in
    alma9|rocky9)
        log_info "Platform: $PLATFORM"
        ;;
    *)
        die "Invalid platform: $PLATFORM (must be alma9 or rocky9)"
        ;;
esac

# Validate version format (YY.MM.patch)
if ! [[ "$VERSION" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
    die "Invalid version format: $VERSION (expected YY.MM.patch, e.g., 25.05.1)"
fi
log_info "Version: $VERSION"

# Check prerequisites
log_info "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || die "Docker not found in PATH"
command -v bash >/dev/null 2>&1 || die "Bash not found in PATH"

# Verify Docker is running
docker info >/dev/null 2>&1 || die "Docker daemon not running or not accessible"
log_info "Docker available: $(docker --version)"

# ============================================================================
# Setup
# ============================================================================

log_section "Setup"

# Resolve output directory
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")"
PLATFORM_OUTPUT="$OUTPUT_DIR/$PLATFORM"
mkdir -p "$PLATFORM_OUTPUT"
log_info "Output directory: $OUTPUT_DIR"
log_info "Platform output: $PLATFORM_OUTPUT"

# Build container paths
WORK_DIR="/tmp/openusd-build-$$"
BUILD_CONTAINER_NAME="openusd-build-${PLATFORM}-${VERSION//./-}-$$"

log_info "Build work directory: $WORK_DIR"
log_info "Build container: $BUILD_CONTAINER_NAME"

# Determine Dockerfile
case "$PLATFORM" in
    alma9)
        DOCKERFILE="docker/Dockerfile.alma9"
        ;;
    rocky9)
        DOCKERFILE="docker/Dockerfile.rocky9"
        ;;
esac

[[ -f "$DOCKERFILE" ]] || die "Dockerfile not found: $DOCKERFILE"
log_info "Dockerfile: $DOCKERFILE"

# Construct tarball URLs
USD_TARBALL_URL="https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v${VERSION}.tar.gz"
log_info "USD tarball URL: $USD_TARBALL_URL"

# ============================================================================
# Docker Image Build (Optional)
# ============================================================================

if [[ $SKIP_IMAGE_BUILD -eq 0 ]]; then
    log_section "Building Docker Image"
    
    IMAGE_TAG="openusd:${PLATFORM}-${VERSION//./-}"
    
    BUILD_CMD=(
        docker build
        --file "$DOCKERFILE"
        --tag "$IMAGE_TAG"
        --build-arg "USD_VERSION=$VERSION"
        --build-arg "USD_TARBALL_URL=$USD_TARBALL_URL"
        --build-arg "PYTHON_VERSION=$PYTHON_VERSION"
        --build-arg "GCCCORE_VERSION=$GCCCORE_VERSION"
        --progress plain
        .
    )
    
    if [[ $DRY_RUN -eq 0 ]]; then
        log_info "Building image: $IMAGE_TAG"
        "${BUILD_CMD[@]}"
    else
        log_info "[DRY RUN] Would execute: ${BUILD_CMD[*]}"
        IMAGE_TAG="openusd:${PLATFORM}-${VERSION//./-}"
    fi
else
    log_section "Skipping Docker Image Build"
    IMAGE_TAG="openusd:${PLATFORM}-${VERSION//./-}"
    log_info "Using existing image: $IMAGE_TAG"
fi

# ============================================================================
# Compilation & Artifact Collection
# ============================================================================

log_section "Compilation"

if [[ $DRY_RUN -eq 0 ]]; then
    # Verify image exists
    docker inspect "$IMAGE_TAG" >/dev/null 2>&1 || die "Docker image not found: $IMAGE_TAG"
    
    # Create temporary work directory in container and run build
    log_info "Starting build container: $BUILD_CONTAINER_NAME"
    
    docker run \
        --name "$BUILD_CONTAINER_NAME" \
        --rm \
        -v "$(pwd):$WORK_DIR" \
        "$IMAGE_TAG" \
        bash -c "
            set -Eeuo pipefail
            
            log() { echo \"[\$(date '+%H:%M:%S')] \$@\" >&2; }
            log 'Build started in $IMAGE_TAG'
            
            # Source toolchain
            source /opt/rh/gcc-toolset-12/enable
            log 'GCC toolset enabled'
            gcc --version | head -1
            g++ --version | head -1
            
            # Verify Python
            test -x '$PYTHON_BIN' || { log 'ERROR: Python not found at $PYTHON_BIN'; exit 1; }
            '$PYTHON_BIN' --version
            
            # Download OpenUSD source
            log 'Downloading OpenUSD $VERSION...'
            mkdir -p /tmp/openusd-src
            curl -fL '$USD_TARBALL_URL' -o /tmp/openusd.tar.gz || { log 'ERROR: Failed to download tarball'; exit 1; }
            log 'Extracting OpenUSD...'
            tar -xzf /tmp/openusd.tar.gz --strip-components=1 -C /tmp/openusd-src
            
            # Run build
            log 'Building OpenUSD...'
            '$PYTHON_BIN' /tmp/openusd-src/build_scripts/build_usd.py \\
                /tmp/openusd-src/_install \\
                --src /tmp/openusd-src/_src \\
                --build /tmp/openusd-src/_build \\
                --inst /tmp/openusd-src/_inst \\
                $(printf '%s ' "${USD_BUILD_FLAGS[@]}")
            
            log 'Build complete'
            
            # Package artifacts
            log 'Packaging artifacts...'
            ARTIFACT_ROOT=\"$WORK_DIR/artifacts/$PLATFORM\"
            mkdir -p \"\$ARTIFACT_ROOT\"
            
            # Python runtime
            log 'Creating Python tarball...'
            tar -C / -czf \"\$ARTIFACT_ROOT/Python_${PYTHON_VERSION}_${PLATFORM}.tar.gz\" \\
                \"${PYTHON_PREFIX#/}\" 2>/dev/null || log 'WARNING: Python tarball creation failed'
            
            # OpenUSD install
            log 'Creating OpenUSD install tarball...'
            tar -C /tmp/openusd-src -czf \"\$ARTIFACT_ROOT/OpenUSD_install_${VERSION}_${PLATFORM}.tar.gz\" _install
            
            # OpenUSD build (for debugging)
            log 'Creating OpenUSD build tarball...'
            tar -C /tmp/openusd-src -czf \"\$ARTIFACT_ROOT/OpenUSD_build_${VERSION}_${PLATFORM}.tar.gz\" _build
            
            # Third-party dependencies
            log 'Creating third-party tarball...'
            tar -C /tmp/openusd-src -czf \"\$ARTIFACT_ROOT/OpenUSD_3rdparty_${VERSION}_${PLATFORM}.tar.gz\" _inst
            
            # Build log
            if [[ -f /tmp/openusd-src/_build/OpenUSD/log.txt ]]; then
                cp /tmp/openusd-src/_build/OpenUSD/log.txt \"\$ARTIFACT_ROOT/build.log\"
                log 'Build log saved'
            fi
            
            # Rez package structure (Python)
            log 'Setting up Rez packages...'
            PY_REZ_ROOT=\"\$ARTIFACT_ROOT/rez/python/${PYTHON_VERSION}\"
            mkdir -p \"\$PY_REZ_ROOT/${PLATFORM}\"
            cp '$WORK_DIR/rez/python/package.py' \"\$PY_REZ_ROOT/package.py\"
            cp -a '${PYTHON_PREFIX}'/* \"\$PY_REZ_ROOT/${PLATFORM}/\"
            
            # Rez package structure (OpenUSD)
            USD_REZ_ROOT=\"\$ARTIFACT_ROOT/rez/openusd/${VERSION}\"
            mkdir -p \"\$USD_REZ_ROOT/${PLATFORM}\"
            cp '$WORK_DIR/rez/openusd/package.py' \"\$USD_REZ_ROOT/package.py\"
            cp -a /tmp/openusd-src/_install/* \"\$USD_REZ_ROOT/${PLATFORM}/\"
            
            log 'Artifacts packaged successfully'
            ls -lh \"\$ARTIFACT_ROOT\"/ | grep -E 'tar.gz|log|package'
        " || die "Build failed in container"
else
    log_info "[DRY RUN] Would run build in container: $IMAGE_TAG"
fi

# ============================================================================
# Verification & Manifest
# ============================================================================

log_section "Verification & Manifest"

if [[ $DRY_RUN -eq 0 ]]; then
    # Verify expected artifacts exist
    log_info "Verifying artifacts..."
    
    REQUIRED_TARBALLS=(
        "$PLATFORM_OUTPUT/OpenUSD_install_${VERSION}_${PLATFORM}.tar.gz"
        "$PLATFORM_OUTPUT/OpenUSD_build_${VERSION}_${PLATFORM}.tar.gz"
        "$PLATFORM_OUTPUT/OpenUSD_3rdparty_${VERSION}_${PLATFORM}.tar.gz"
    )
    
    MISSING_ARTIFACTS=0
    for tarball in "${REQUIRED_TARBALLS[@]}"; do
        if [[ -f "$tarball" ]]; then
            SIZE=$(du -h "$tarball" | cut -f1)
            SHA256=$(sha256sum "$tarball" | cut -d' ' -f1)
            log_info "✓ $(basename "$tarball") ($SIZE) $SHA256"
        else
            log_error "✗ Missing: $(basename "$tarball")"
            MISSING_ARTIFACTS=$((MISSING_ARTIFACTS + 1))
        fi
    done
    
    if [[ $MISSING_ARTIFACTS -gt 0 ]]; then
        die "Verification failed: $MISSING_ARTIFACTS required artifacts missing"
    fi
    
    # Verify Rez packages
    if [[ -d "$PLATFORM_OUTPUT/rez/python/${PYTHON_VERSION}/${PLATFORM}" ]]; then
        log_info "✓ Python Rez package"
    else
        log_warn "Missing Python Rez package"
    fi
    
    if [[ -d "$PLATFORM_OUTPUT/rez/openusd/${VERSION}/${PLATFORM}" ]]; then
        log_info "✓ OpenUSD Rez package"
    else
        log_warn "Missing OpenUSD Rez package"
    fi
    
    # Generate manifest
    log_info "Generating manifest..."
    MANIFEST_FILE="$PLATFORM_OUTPUT/manifest.json"
    
    cat > "$MANIFEST_FILE" <<EOF
{
  "build_info": {
    "openusd_version": "$VERSION",
    "platform": "$PLATFORM",
    "python_version": "$PYTHON_VERSION",
    "gcc_version": "$GCCCORE_VERSION",
    "build_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_script": "scripts/build-openusd.sh",
    "build_flags": [$(printf '"%s",' "${USD_BUILD_FLAGS[@]}" | sed 's/,$//')],
    "docker_image": "$IMAGE_TAG"
  },
  "artifacts": {
EOF
    
    # Add artifacts to manifest
    for tarball in "$PLATFORM_OUTPUT"/*.tar.gz "$PLATFORM_OUTPUT"/*.log; do
        if [[ -f "$tarball" ]]; then
            BASENAME=$(basename "$tarball")
            SIZE=$(stat --format=%s "$tarball")
            SHA256=$(sha256sum "$tarball" | cut -d' ' -f1)
            {
                echo "    \"$BASENAME\": {"
                echo "      \"size_bytes\": $SIZE,"
                echo "      \"sha256\": \"$SHA256\""
                echo "    },"
            } >> "$MANIFEST_FILE"
        fi
    done
    
    # Remove trailing comma from last artifact and close JSON
    sed -i '$ s/,$//' "$MANIFEST_FILE"
    cat >> "$MANIFEST_FILE" <<EOF
  },
  "directories": {
    "python_rez": "rez/python/${PYTHON_VERSION}/${PLATFORM}",
    "openusd_rez": "rez/openusd/${VERSION}/${PLATFORM}"
  }
}
EOF
    
    log_info "Manifest written: $MANIFEST_FILE"
fi

# ============================================================================
# Completion
# ============================================================================

log_section "Build Complete"

if [[ $DRY_RUN -eq 0 ]]; then
    log_info "Platform: $PLATFORM"
    log_info "Version: $VERSION"
    log_info "Output: $PLATFORM_OUTPUT"
    log_info ""
    log_info "Artifacts:"
    find "$PLATFORM_OUTPUT" \( -name '*.tar.gz' -o -name '*.log' \) -exec ls -lh {} \; 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    log_info ""
    log_info "Build succeeded!"
    exit 0
else
    log_info "[DRY RUN] Build simulation complete"
    log_info "To execute the build, remove the --dry-run flag"
    exit 0
fi
