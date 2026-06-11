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
# Ensure terminfo directory exists and contains tmux entries to prevent nfpm from failing
echo "Generating terminfo..."
mkdir -p terminfo
if [ -f "tmux.info" ]; then
    tic -x -o terminfo tmux.info || true
fi
# If tmux.info does not exist or tic failed, copy system terminfo entries
if [ ! -f "terminfo/t/tmux" ] && [ ! -f "terminfo/t/tmux-256color" ]; then
    # Try to copy system tmux terminfo entries preserving directory structure
    for src in $(find /usr/share/terminfo -name "tmux*" 2>/dev/null); do
        # Get the relative path (e.g., t/tmux) and recreate it
        rel="${src#/usr/share/terminfo/}"
        dst_dir="terminfo/$(dirname "$rel")"
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/" || true
    done
fi
# If we still have no terminfo, install ncurses-term to get them
if [ ! -f "terminfo/t/tmux" ] && [ ! -f "terminfo/t/tmux-256color" ]; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y ncurses-term 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ncurses-term 2>/dev/null || true
    fi
    # Re-try copying
    for src in $(find /usr/share/terminfo -name "tmux*" 2>/dev/null); do
        rel="${src#/usr/share/terminfo/}"
        dst_dir="terminfo/$(dirname "$rel")"
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/" || true
    done
fi

# Download nfpm
NFPM_VERSION="2.41.0"
echo "Downloading nfpm ${NFPM_VERSION}..."
curl -sL "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_${ARCH}.tar.gz" | tar -xz -C /usr/local/bin nfpm

# Prepare files for nfpm
mkdir -p /tmp/nfpm-build
cp tmux /tmp/nfpm-build/
cp tmux.1 /tmp/nfpm-build/ || true
cp example_tmux.conf /tmp/nfpm-build/ || true
cp CHANGES /tmp/nfpm-build/ || true
# Copy license file (may be LICENSE, LICENSE.md, COPYING, etc.)
cp LICENSE /tmp/nfpm-build/ 2>/dev/null || cp LICENSE.md /tmp/nfpm-build/ 2>/dev/null || cp COPYING /tmp/nfpm-build/ 2>/dev/null || true
cp README /tmp/nfpm-build/ 2>/dev/null || cp README.md /tmp/nfpm-build/ 2>/dev/null || true
if [ -d terminfo ]; then
    # Check if terminfo has any files
    if [ -n "$(find terminfo -type f 2>/dev/null)" ]; then
        cp -r terminfo /tmp/nfpm-build/ || true
    else
        echo "Warning: terminfo directory is empty, skipping terminfo packaging"
    fi
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

# If terminfo is not present, create a temporary nfpm config without the tree entry
if [ ! -d "terminfo" ] || [ -z "$(find terminfo -type f 2>/dev/null)" ]; then
    echo "Creating temporary nfpm config without terminfo..."
    TMP_CONFIG="/tmp/nfpm-config-${PKG_TYPE}.yaml"
    # Remove the terminfo tree entry from the config
    sed '/^  - src: .\/terminfo$/,/^    type: tree$/d' "$NFPM_CONFIG" > "$TMP_CONFIG"
    NFPM_CONFIG="$TMP_CONFIG"
fi

# Build package with nfpm
echo "Building ${PKG_TYPE} package..."
ARCH="$NFPM_ARCH" VERSION="$VERSION" nfpm pkg -f "$NFPM_CONFIG" -p "$PKG_TYPE" -t "$OUTPUT_NAME"

# Move to output
mkdir -p /output
cp "$OUTPUT_NAME" /output/

echo "Package generated: $OUTPUT_NAME"
ls -la /output/
