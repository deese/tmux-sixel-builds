#!/usr/bin/env bash
set -euo pipefail

DISTRO="$1"
VERSION="$2"
ARCH="$(uname -m)"

# Map architecture for nfpm
if [ "$ARCH" == "x86_64" ]; then
    NFPM_ARCH="amd64"
else
    NFPM_ARCH="$ARCH"
fi

WORKDIR="/tmp/tmux-build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Install dependencies based on distro
case "$DISTRO" in
    ubuntu-*|debian-*)
        apt-get update
        apt-get install -y \
            build-essential \
            libevent-dev \
            libncurses-dev \
            bison \
            pkg-config \
            wget \
            libsixel-dev \
            libutf8proc-dev \
            curl \
            && rm -rf /var/lib/apt/lists/*
        ;;
    epel-*)
        dnf install -y \
            gcc \
            make \
            libevent-devel \
            ncurses-devel \
            bison \
            pkgconfig \
            wget \
            curl \
            dnf-plugins-core
        
        # Enable CRB (CodeReady Builder) for Rocky
        dnf config-manager --set-enabled crb || true
        
        # Install EPEL
        dnf install -y epel-release
        
        # Install EPEL dependencies
        dnf install -y \
            libsixel-devel \
            utf8proc-devel \
        ;;
    *)
        echo "Unsupported distro: $DISTRO"
        exit 1
        ;;
esac

# Download tmux
echo "Downloading tmux ${VERSION}..."
wget "https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz"
tar -xzf "tmux-${VERSION}.tar.gz"
cd "tmux-${VERSION}"

# Compile
echo "Configuring and compiling..."
./configure --prefix=/usr --enable-sixel
make -j$(nproc)

# Generate terminfo
echo "Generating terminfo..."
if [ -f "tmux.info" ]; then
    mkdir -p terminfo
    tic -x -o terminfo tmux.info
fi

# Download nfpm
NFPM_VERSION="2.41.0"
echo "Downloading nfpm ${NFPM_VERSION}..."
curl -sL "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_${NFPM_ARCH}.tar.gz" | tar -xz -C /usr/local/bin nfpm

# Prepare files for nfpm
mkdir -p /tmp/nfpm-build
cp tmux /tmp/nfpm-build/
cp tmux.1 /tmp/nfpm-build/ || true
cp example_tmux.conf /tmp/nfpm-build/ || true
cp CHANGES /tmp/nfpm-build/ || true
cp LICENSE /tmp/nfpm-build/ || true
cp README /tmp/nfpm-build/ || true
if [ -d terminfo ]; then
    cp -r terminfo /tmp/nfpm-build/
fi

cd /tmp/nfpm-build

# Determine package type
if [[ "$DISTRO" == ubuntu-* ]] || [[ "$DISTRO" == debian-* ]]; then
    PKG_TYPE="deb"
    NFPM_CONFIG="/repo/nfpm/deb.yaml"
    OUTPUT_NAME="tmux-${VERSION}-${DISTRO}_${NFPM_ARCH}.deb"
else
    PKG_TYPE="rpm"
    NFPM_CONFIG="/repo/nfpm/rpm.yaml"
    if [[ "$DISTRO" == "epel-9" ]]; then
        OUTPUT_NAME="tmux-${VERSION}-el9.${NFPM_ARCH}.rpm"
    else
        OUTPUT_NAME="tmux-${VERSION}-el10.${NFPM_ARCH}.rpm"
    fi
fi

# Build package with nfpm
echo "Building ${PKG_TYPE} package..."
ARCH="$NFPM_ARCH" VERSION="$VERSION" nfpm pkg -f "$NFPM_CONFIG" -p "$PKG_TYPE" -t "$OUTPUT_NAME"

# Move to output
mkdir -p /output
cp "$OUTPUT_NAME" /output/

echo "Package generated: $OUTPUT_NAME"
ls -la /output/
