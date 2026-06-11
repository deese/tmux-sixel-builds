Name:           tmux
Version:        %{tmux_version}
Release:        1%{?dist}
Summary:        Terminal multiplexer with image support (Sixel + Kitty)

License:        ISC
URL:            https://github.com/tmux/tmux
Source0:         https://github.com/tmux/tmux/releases/download/%{version}/tmux-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  libevent-devel
BuildRequires:  ncurses-devel
BuildRequires:  bison
BuildRequires:  pkgconfig
BuildRequires:  libsixel-devel
BuildRequires:  utf8proc-devel

Requires:       libevent
Requires:       ncurses-libs
Requires:       libsixel
Requires:       utf8proc

Provides:       tmux-terminfo
Obsoletes:      tmux-terminfo

%description
Terminal multiplexer with image support (Sixel + Kitty).

%prep
%autosetup -n tmux-%{version}

%build
%configure --prefix=%{_prefix} --enable-sixel
%make_build

%install
%make_install

# Ensure terminfo is present
mkdir -p %{buildroot}%{_datadir}/terminfo
if [ -f tmux.info ]; then
    tic -x -o %{buildroot}%{_datadir}/terminfo tmux.info || true
fi
# Fallback: copy system terminfo entries
if [ ! -f %{buildroot}%{_datadir}/terminfo/t/tmux ] && [ ! -f %{buildroot}%{_datadir}/terminfo/t/tmux-256color ]; then
    for src in $(find %{_datadir}/terminfo -name "tmux*" 2>/dev/null); do
        rel="${src#%{_datadir}/terminfo/}"
        dst_dir="%{buildroot}%{_datadir}/terminfo/$(dirname "$rel")"
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/" || true
    done
fi

mkdir -p %{buildroot}%{_datadir}/doc/tmux
if [ -f example_tmux.conf ]; then
    cp example_tmux.conf %{buildroot}%{_datadir}/doc/tmux/
fi

%files
%license COPYING
%doc CHANGES README
%{_bindir}/tmux
%{_mandir}/man1/tmux.1*
%{_datadir}/doc/tmux/example_tmux.conf
%{_datadir}/terminfo

%changelog
* Thu Jun 11 2026 Auto Builder <build@localhost> - %{version}-1
- Initial packaging for tmux-sixel-builds
