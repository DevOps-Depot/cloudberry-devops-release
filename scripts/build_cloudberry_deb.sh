#!/bin/bash

# Script to build a .deb package for Cloudberry Database

# Usage:
#   ./build_cloudberry_deb.sh [VERSION]
# Example:
#   ./build_cloudberry_deb.sh 1.6.0~rc2-1
#   ./build_cloudberry_deb.sh  # Uses the default version 1.6.0~rc1-1

# Check for required tools
REQUIRED_TOOLS=("dpkg-deb" "sed" "cp" "rmdir")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS+=($tool)
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "Error: The following required tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo "Please install them before running this script."
    exit 1
fi

# Variables
VERSION="${1:-1.6.0-1}"

# Extract base version (e.g., 1.6.0 from 1.6.0~rc1-1)
BASE_VERSION=$(echo $VERSION | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

# Other variables
PACKAGE_NAME="cloudberry-db"  # Package name
ARCH="amd64"  # Architecture
INSTALL_DIR="/usr/local/${PACKAGE_NAME}-${BASE_VERSION}"  # Installation directory based on the base version
SYMLINK_DIR="/usr/local/${PACKAGE_NAME}"  # Symlink to the installation directory
BUILD_DIR=~/cloudberry-db-deb  # Directory where the .deb package is built
DEB_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"  # Name of the .deb file
MAINTAINER="Cloudberry Open Source <cloudberrydb@gmail.com>"  # Maintainer information

# Step 1: Create directory structure
echo "Setting up directory structure..."
mkdir -p ${BUILD_DIR}/DEBIAN  # Create the DEBIAN directory for control files
mkdir -p ${BUILD_DIR}${INSTALL_DIR}  # Create the installation directory

# Step 2: Copy the built files to the installation directory
echo "Copying built files to ${INSTALL_DIR}..."
cp -r /usr/local/cloudberry-db/* ${BUILD_DIR}${INSTALL_DIR}  # Copy the files from the source directory

# Step 3: Create control file with package metadata
echo "Creating control file..."
cat <<EOL > ${BUILD_DIR}/DEBIAN/control
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: database
Priority: optional
Architecture: ${ARCH}
Essential: no
Depends: libbrotli1, libcurl3-gnutls, libcurl4, libffi8, libgmp10, libgnutls30, libgssapi-krb5-2, libhogweed6, libicu70, libidn2-0, libk5crypto3, libkrb5-3, libkrb5support0, libldap-2.5-0, liblz4-1, libnettle8, libnghttp2-14, libp11-kit0, libpsl5, librtmp1, libsasl2-2, libssh-4, libssl3, libtasn1-6, libunistring2, libxerces-c3.2, libxml2, libzstd1
Maintainer: ${MAINTAINER}
Description: High-performance, open-source data warehouse based on PostgreSQL/Greenplum
 Cloudberry Database is an advanced, open-source, massively parallel
 processing (MPP) data warehouse developed from PostgreSQL and
 Greenplum. It is designed for high-performance analytics on
 large-scale data sets, offering powerful analytical capabilities and
 enhanced security features.
 .
 Key Features:
 .
 - Massively parallel processing for optimized performance
 - Advanced analytics for complex data processing
 - Integration with ETL and BI tools
 - Compatibility with multiple data sources and formats
 - Enhanced security features
 .
 Cloudberry Database supports both batch processing and real-time data
 warehousing, making it a versatile solution for modern data
 environments.
 .
 For more information, visit the official Cloudberry Database website
 at https://cloudberrydb.org.
EOL

# Step 4: Create post-installation script
echo "Creating postinst script..."
cat <<EOL > ${BUILD_DIR}/DEBIAN/postinst
#!/bin/bash

# Create symlink to the installation directory
if [ -L ${SYMLINK_DIR} ] || [ -e ${SYMLINK_DIR} ]; then
    rm -f ${SYMLINK_DIR}
fi
ln -s ${INSTALL_DIR} ${SYMLINK_DIR}

# Change ownership of the installation directory and symlink
if id "gpadmin" &>/dev/null; then
    chown -R gpadmin:gpadmin ${INSTALL_DIR}
    chown -h gpadmin:gpadmin ${SYMLINK_DIR}
else
    chown -R root.root ${INSTALL_DIR}
    chown -h root.root ${SYMLINK_DIR}
fi

exit 0
EOL

chmod 755 ${BUILD_DIR}/DEBIAN/postinst  # Make the postinst script executable

# Step 5: Create post-removal script
echo "Creating postrm script..."
cat <<EOL > ${BUILD_DIR}/DEBIAN/postrm
#!/bin/bash

# Remove the symlink during package removal
if [ -L "${SYMLINK_DIR}" ]; then
    rm -f "${SYMLINK_DIR}"
fi

# Remove the specific installation directory if it is empty
if [ -d "${INSTALL_DIR}" ]; then
    rmdir --ignore-fail-on-non-empty "${INSTALL_DIR}"
fi

exit 0
EOL

chmod 755 ${BUILD_DIR}/DEBIAN/postrm  # Make the postrm script executable

# Step 6: Build the .deb package
echo "Building the .deb package..."
dpkg-deb --build ${BUILD_DIR} ~/${DEB_FILE}

echo "Package build complete: ~/${DEB_FILE}"
