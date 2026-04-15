#!/bin/bash
set -e

CORROSION_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}

./build_corrosion_debian.sh "$CORROSION_VERSION" "$BUILD_VERSION" "$ARCH"
./build_corrosion_ubuntu.sh "$CORROSION_VERSION" "$BUILD_VERSION" "$ARCH"
