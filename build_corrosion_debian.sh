#!/bin/bash
set -e

CORROSION_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}

if [ -z "$CORROSION_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <corrosion_version> <build_version> [architecture]"
    echo "Example: $0 2025.11.4 1 amd64"
    echo "Example: $0 2025.11.4 1 arm64"
    echo "Example: $0 2025.11.4 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64"
    exit 1
fi

get_corrosion_arch() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "x86_64-unknown-linux-gnu"
            ;;
        "arm64")
            echo "aarch64-unknown-linux-gnu"
            ;;
        *)
            echo ""
            ;;
    esac
}

build_architecture() {
    local build_arch=$1
    local release_arch

    release_arch=$(get_corrosion_arch "$build_arch")
    if [ -z "$release_arch" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    echo "Building for architecture: $build_arch"

    declare -a arr=("bookworm" "trixie" "forky" "sid")

    for dist in "${arr[@]}"; do
        FULL_VERSION="${CORROSION_VERSION}-${BUILD_VERSION}+${dist}_${build_arch}"
        echo "  Building corrosion $FULL_VERSION"

        local tarball="corrosion-${release_arch}.tar.gz"
        rm -f "$tarball"
        if ! wget "https://github.com/psviderski/corrosion/releases/download/v${CORROSION_VERSION}/${tarball}"; then
            echo "❌ Failed to download corrosion binary for $build_arch"
            return 1
        fi
        mkdir -p "build/${build_arch}"
        tar -xzf "$tarball" -C "build/${build_arch}"
        rm -f "$tarball"

        if ! docker build . -f Dockerfile -t "uncloud-corrosion-$dist-$build_arch" \
            --build-arg CORROSION_VERSION="$CORROSION_VERSION" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch"; then
            echo "❌ Failed to build Docker image for corrosion $dist on $build_arch"
            rm -rf "build/${build_arch}"
            return 1
        fi

        id="$(docker create "uncloud-corrosion-$dist-$build_arch")"
        docker cp "$id:/uncloud-corrosion_$FULL_VERSION.deb" - > "./uncloud-corrosion_$FULL_VERSION.deb"
        tar -xf "./uncloud-corrosion_$FULL_VERSION.deb"
        rm -rf "build/${build_arch}"
    done

    echo "✅ Successfully built for $build_arch"
    return 0
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building corrosion $CORROSION_VERSION-$BUILD_VERSION for all Debian distributions..."
    echo ""

    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la uncloud-corrosion_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
