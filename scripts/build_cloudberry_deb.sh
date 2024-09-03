#!/bin/bash

# Cloudberry DB Debian Package Build Script

set -euo pipefail

# Uncomment the following line for debugging
# set -x

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -p, --packages-dir DIR  Specify the packages directory (default: packaging/deb/ubuntu22/package_files)"
    echo "  -c, --component NAME    Specify a single component to build (e.g., cloudberry-db, cloudberry-hll)"
    echo "  -h, --help              Display this help message"
    exit 1
}

# Check for required tools
REQUIRED_TOOLS=("dpkg-deb" "sed" "cp" "rmdir" "envsubst" "realpath")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required tool '$tool' is not installed." >&2
        exit 1
    fi
done

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_PACKAGE_FILES_DIR="${REPO_ROOT}/packaging/deb/ubuntu22/package_files"
BUILD_BASE_DIR="${HOME}/cloudberry-db-deb-build"

# Parse command-line options
PACKAGE_FILES_DIR=""
SPECIFIC_COMPONENT=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--packages-dir)
            PACKAGE_FILES_DIR="$2"
            shift 2
            ;;
        -c|--component)
            SPECIFIC_COMPONENT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# If no packages directory specified, use the default
if [[ -z "$PACKAGE_FILES_DIR" ]]; then
    PACKAGE_FILES_DIR="$DEFAULT_PACKAGE_FILES_DIR"
fi

# Convert to absolute path if relative
PACKAGE_FILES_DIR=$(realpath -m "$PACKAGE_FILES_DIR")

# Check if the packages directory exists
if [[ ! -d "$PACKAGE_FILES_DIR" ]]; then
    echo "Error: Packages directory '$PACKAGE_FILES_DIR' does not exist." >&2
    exit 1
fi

# Function to build a component package
build_component_package() {
    local component="$1"

    echo "Building package for ${component}..."

    # Check if the component directory exists
    if [[ ! -d "${PACKAGE_FILES_DIR}/${component}" ]]; then
        echo "Error: Component directory '${PACKAGE_FILES_DIR}/${component}' does not exist." >&2
        return 1
    fi

    # Check if the metadata file exists
    if [[ ! -f "${PACKAGE_FILES_DIR}/${component}/metadata" ]]; then
        echo "Error: Metadata file for component '${component}' does not exist." >&2
        return 1
    fi

    # Source the metadata file
    # shellcheck source=/dev/null
    source "${PACKAGE_FILES_DIR}/${component}/metadata"

    # Set up build directory
    local BUILD_DIR="${BUILD_BASE_DIR}/${PACKAGE_NAME}"
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}/DEBIAN"
    mkdir -p "${BUILD_DIR}${INSTALL_DIR}"

    # Copy component files (if they exist)
    if [[ -d "${PACKAGE_FILES_DIR}/${component}/files" ]]; then
        cp -r "${PACKAGE_FILES_DIR}/${component}/files/"* "${BUILD_DIR}${INSTALL_DIR}/"
    fi

    # Create control file
    envsubst < "${PACKAGE_FILES_DIR}/common/control_template" > "${BUILD_DIR}/DEBIAN/control"

    # Create postinst script (if template exists)
    if [[ -f "${PACKAGE_FILES_DIR}/common/postinst_template" ]]; then
        envsubst < "${PACKAGE_FILES_DIR}/common/postinst_template" > "${BUILD_DIR}/DEBIAN/postinst"
        chmod 755 "${BUILD_DIR}/DEBIAN/postinst"
    fi

    # Create postrm script
    envsubst < "${PACKAGE_FILES_DIR}/common/postrm_template" > "${BUILD_DIR}/DEBIAN/postrm"
    chmod 755 "${BUILD_DIR}/DEBIAN/postrm"

    # Build the .deb package
    dpkg-deb --build "${BUILD_DIR}" "${HOME}/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

    echo "Package built: ${HOME}/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
}

# Main execution
main() {
    echo "Using packages directory: $PACKAGE_FILES_DIR"

    # Create necessary directories
    mkdir -p "${BUILD_BASE_DIR}"

    if [[ -n "$SPECIFIC_COMPONENT" ]]; then
        # Build only the specified component
        build_component_package "$SPECIFIC_COMPONENT"
    else
        # Build packages for each component
        while IFS= read -r -d '' component_dir; do
            component=$(basename "$component_dir")
            if [[ "$component" != "common" && -f "${component_dir}/metadata" ]]; then
                build_component_package "$component"
            fi
        done < <(find "${PACKAGE_FILES_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    echo "All specified packages built successfully."
}

main "$@"
