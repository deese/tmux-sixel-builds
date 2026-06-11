#!/usr/bin/env bash
set -euo pipefail

DISTRO="$1"
VERSION="$2"
ARCH="$(uname -m)"

# Map architecture for nfpm (DEB builds)
if [ "$ARCH" == "x86_64" ]; then
    NFPM_ARCH="amd64"
else
    NFPM_ARCH="$ARCH"
fi

WORKDIR="/tmp/tmux-build"
mkdir -p "$WORKDIR"

build_deb() {
    cd "$WORKDIR"

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
    mkdir -p terminfo
    if [ -f "tmux.info" ]; then
        tic -x -o terminfo tmux.info || true
    fi
    # NOTE: For DEB builds, do NOT copy system terminfo files into the package.
    # Modern ncurses-base (e.g., 6.6+20251231) already provides tmux terminfo entries.
    # Including them causes dpkg conflicts with ncurses-base.
    # If tmux.info is missing, we simply skip terminfo packaging; the target
    # system will rely on ncurses-base (a dependency of libncurses6).

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
    cp LICENSE /tmp/nfpm-build/ 2>/dev/null || cp LICENSE.md /tmp/nfpm-build/ 2>/dev/null || cp COPYING /tmp/nfpm-build/ 2>/dev/null || true
    cp README /tmp/nfpm-build/ 2>/dev/null || cp README.md /tmp/nfpm-build/ 2>/dev/null || true
    if [ -d terminfo ]; then
        if [ -n "$(find terminfo -type f 2>/dev/null)" ]; then
            cp -r terminfo /tmp/nfpm-build/ || true
        else
            echo "Warning: terminfo directory is empty, skipping terminfo packaging"
        fi
    fi

    cd /tmp/nfpm-build

    PKG_TYPE="deb"
    NFPM_CONFIG="/repo/nfpm/deb.yaml"
    PKG_DISTRO="${ARTIFACT_NAME:-${DISTRO}}"
    OUTPUT_NAME="tmux-${VERSION}-${PKG_DISTRO}_${NFPM_ARCH}.deb"

    if [ ! -d "terminfo" ] || [ -z "$(find terminfo -type f 2>/dev/null)" ]; then
        echo "Creating temporary nfpm config without terminfo..."
        TMP_CONFIG="/tmp/nfpm-config-${PKG_TYPE}.yaml"
        sed '/^  - src: .\/terminfo$/,/^    type: tree$/d' "$NFPM_CONFIG" > "$TMP_CONFIG"
        NFPM_CONFIG="$TMP_CONFIG"
    fi

    echo "Building ${PKG_TYPE} package..."
    ARCH="$NFPM_ARCH" VERSION="$VERSION" nfpm pkg -f "$NFPM_CONFIG" -p "$PKG_TYPE" -t "$OUTPUT_NAME"

    mkdir -p /output
    cp "$OUTPUT_NAME" /output/

    echo "Package generated: $OUTPUT_NAME"
    ls -la /output/
}

build_rpm() {
    echo "Installing RPM build tools..."
    dnf install -y \
        dnf-plugins-core \
        rpm-build \
        rpmdevtools \
        gcc \
        make \
        wget

    # Enable CRB for additional build deps (meson, gd-devel, etc.)
    dnf config-manager --set-enabled crb || true
    dnf install -y epel-release || true

    dnf install -y \
        meson \
        gd-devel \
        libjpeg-devel \
        libpng-devel \
        libevent-devel \
        ncurses-devel \
        bison \
        pkgconfig \
        ncurses-term

    echo "Setting up rpmbuild tree..."
    rpmdev-setuptree

    local SOURCES="${HOME}/rpmbuild/SOURCES"
    local SPECS="${HOME}/rpmbuild/SPECS"
    local RPMS="${HOME}/rpmbuild/RPMS"

    echo "Downloading sources..."
    cd "$SOURCES"

    wget -q "https://github.com/libsixel/libsixel/archive/v1.10.5/libsixel-1.10.5.tar.gz"
    wget -q "https://github.com/JuliaLang/utf8proc/archive/v2.11.3/utf8proc-v2.11.3.tar.gz"
    wget -q "https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz"

    echo "Copying specs..."
    cp /repo/specs/*.spec "$SPECS/"

    # Build libsixel
    echo "Building libsixel..."
    rpmbuild -ba "$SPECS/libsixel.spec"

    echo "Installing libsixel RPMs..."
    dnf install -y "${RPMS}"/*/*libsixel-*.rpm || true

    # Build utf8proc
    echo "Building utf8proc..."
    rpmbuild -ba "$SPECS/utf8proc.spec"

    echo "Installing utf8proc RPMs..."
    dnf install -y "${RPMS}"/*/*utf8proc-*.rpm || true

    # Build tmux
    echo "Building tmux..."
    rpmbuild --define "tmux_version ${VERSION}" -ba "$SPECS/tmux.spec"

    # Copy all RPMs to output
    mkdir -p /output
    find "${RPMS}" -name "*.rpm" -exec cp {} /output/ \;

    echo "Packages generated:"
    ls -la /output/
}

case "$DISTRO" in
    ubuntu-*|debian-*)
        build_deb
        ;;
    epel-*)
        build_rpm
        ;;
    *)
        echo "Unsupported distro: $DISTRO"
        exit 1
        ;;
esac
