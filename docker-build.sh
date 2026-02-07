#!/bin/bash
set -e

# Docker build script for cosmic-ext-applet-clipboard-manager
# Builds in Docker and installs to host system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="cosmic-ext-applet-clipboard-manager"
CONTAINER_NAME="cosmic-clipboard-build"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
BUILD_ONLY=false
for arg in "$@"; do
    case $arg in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --prefix=*)
            INSTALL_PREFIX="${arg#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only       Only build, don't install to host"
            echo "  --prefix=PATH      Set installation prefix (default: /usr)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  INSTALL_PREFIX     Installation prefix (default: /usr)"
            exit 0
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Build the Docker image
log_info "Building Docker image..."
docker build -t "$CONTAINER_NAME" .

# Create a temporary container to extract artifacts
log_info "Creating temporary container..."
CONTAINER_ID=$(docker create "$CONTAINER_NAME")

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary container..."
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Extract the built binary
log_info "Extracting build artifacts..."
mkdir -p "${SCRIPT_DIR}/target/docker-release"
docker cp "${CONTAINER_ID}:/build/target/release/${PROJECT_NAME}" "${SCRIPT_DIR}/target/docker-release/"

log_info "Binary extracted to: ${SCRIPT_DIR}/target/docker-release/${PROJECT_NAME}"

# Also copy other required files from container
for file in res/desktop_entry.desktop res/metainfo.xml res/app_icon.svg; do
    if docker cp "${CONTAINER_ID}:/build/${file}" "${SCRIPT_DIR}/${file}" 2>/dev/null; then
        : # file copied successfully
    fi
done

if [ "$BUILD_ONLY" = true ]; then
    log_info "Build-only mode. Artifacts available in target/docker-release/"
    log_info "To install manually, run:"
    log_info "  sudo install -Dm0755 target/docker-release/${PROJECT_NAME} ${INSTALL_PREFIX}/bin/${PROJECT_NAME}"
    exit 0
fi

# Install to host system
log_info "Installing to host system (prefix: ${INSTALL_PREFIX})..."

# Check if we need sudo
if [ -w "${INSTALL_PREFIX}/bin" ] 2>/dev/null || [ -w "${INSTALL_PREFIX}" ] 2>/dev/null; then
    SUDO=""
else
    log_warn "Installation requires sudo privileges..."
    SUDO="sudo"
fi

# Install binary
$SUDO install -Dm0755 "${SCRIPT_DIR}/target/docker-release/${PROJECT_NAME}" "${INSTALL_PREFIX}/bin/${PROJECT_NAME}"

# Install desktop file
$SUDO install -Dm0644 "${SCRIPT_DIR}/res/desktop_entry.desktop" "${INSTALL_PREFIX}/share/applications/io.github.cosmic_utils.${PROJECT_NAME}.desktop"

# Install metainfo
$SUDO install -Dm0644 "${SCRIPT_DIR}/res/metainfo.xml" "${INSTALL_PREFIX}/share/metainfo/io.github.cosmic_utils.${PROJECT_NAME}.metainfo.xml"

# Install icon
$SUDO install -Dm0644 "${SCRIPT_DIR}/res/app_icon.svg" "${INSTALL_PREFIX}/share/icons/hicolor/scalable/apps/io.github.cosmic_utils.${PROJECT_NAME}-symbolic.svg"

log_info "Installation complete!"
log_info "Binary installed to: ${INSTALL_PREFIX}/bin/${PROJECT_NAME}"

# Optionally restart COSMIC panel to pick up the applet
if command -v pkill >/dev/null 2>&1; then
    log_info "To test the applet in the panel, run: pkill cosmic-panel"
fi
