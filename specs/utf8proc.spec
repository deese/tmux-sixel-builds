Summary: Library for processing UTF-8 encoded Unicode strings
Name:    utf8proc
Version: 2.11.3
Release: 1%{?dist}
License: MIT AND Unicode-DFS-2015
URL:     http://julialang.org/utf8proc/
Source0:  https://github.com/JuliaLang/utf8proc/archive/v%{version}.tar.gz#/%{name}-v%{version}.tar.gz

BuildRequires: make
BuildRequires: gcc

%description
utf8proc is a library for processing UTF-8 encoded Unicode strings.
Some features are Unicode normalization, stripping of default ignorable
characters, case folding and detection of grapheme cluster boundaries.
A special character mapping is available, which converts for example
the characters "Hyphen" (U+2010), "Minus" (U+2212) and "Hyphen-Minus
(U+002D, ASCII Minus) all into the ASCII minus sign, to make them
equal for comparisons.

This package only contains the C library.

%package devel
Summary:  Header files, libraries and development documentation for %{name}
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Contains header files for developing applications that use the %{name}
library.

%prep
%autosetup -n utf8proc-%{version}

%build
%set_build_flags
%make_build

%install
make install DESTDIR=%{buildroot} prefix=%{_prefix} includedir=%{_includedir} libdir=%{_libdir}
rm -f %{buildroot}%{_libdir}/libutf8proc.a

%files
%doc LICENSE.md NEWS.md README.md
%{_libdir}/libutf8proc.so.3*

%files devel
%{_includedir}/utf8proc.h
%{_libdir}/libutf8proc.so
%{_libdir}/pkgconfig/libutf8proc.pc

%changelog
* Thu Jun 11 2026 Auto Builder <build@localhost> - 2.11.3-1
- Initial packaging for tmux-sixel-builds
