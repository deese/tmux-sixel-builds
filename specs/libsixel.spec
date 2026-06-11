Name:           libsixel
Version:        1.10.5
Release:        1%{?dist}
Summary:        SIXEL encoding and decoding

License:        MIT
URL:            https://github.com/libsixel/libsixel
Source0:         %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  pkgconfig(gdlib)
BuildRequires:  pkgconfig(libjpeg)
BuildRequires:  pkgconfig(libpng)

%description
An encoder/decoder implementation for DEC SIXEL graphics.

%package devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
%{summary}.

%package utils
Summary:        SIXEL encoder and decoder utilities
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description utils
%{summary}.

%prep
%autosetup

%build
%meson -Dtests=disabled
%meson_build

%install
%meson_install

%files
%license LICENSE
%doc AUTHORS
%doc NEWS
%doc README.md
%{_libdir}/libsixel.so.1
%{_libdir}/libsixel.so.1.0.0

%files devel
%{_bindir}/libsixel-config
%{_includedir}/sixel.h
%{_libdir}/libsixel.so
%{_libdir}/pkgconfig/libsixel.pc

%files utils
%{_bindir}/img2sixel
%{_bindir}/sixel2png
%{_mandir}/man1/img2sixel.1*
%{_mandir}/man1/sixel2png.1*
%{_datadir}/bash-completion/completions/img2sixel
%{_datadir}/zsh/site-functions/_img2sixel

%changelog
* Thu Jun 11 2026 Auto Builder <build@localhost> - 1.10.5-1
- Initial packaging for tmux-sixel-builds
