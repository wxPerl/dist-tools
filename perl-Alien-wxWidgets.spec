# RPM spec file for wxPerl

%define blr /var/tmp/perl-Alien-wxWidgets-buildroot/
%define ver <% $ver %>
%define full_ver <% $full_ver %>
%define rel <% $release %>
%define wx_version <% $wxgtk_version %>
%define makefile_flags <% $makefile_flags %>

Summary: Alien::wxWidgets - Perl-available information about wxWidgets
Name: perl-Alien-wxWidgets
Version: %{full_ver}
Release: %{rel}
Copyright: This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
Group: # 
Source: http://prdownload.sourceforge.net/wxperl/Alien-wxWidgets-%{full_ver}.tar.gz
# Patch: Wx-0.08.patch
Url: http://wxperl.sourceforge.net/
BuildRoot: %{blr}
BuildRequires: perl >= 5.006 , wx-gtk2-unicode-gl >= %{wx_version}, wx-gtk2-unicode-contrib-devel >= %{wx_version}
Requires: wx-gtk2-unicode-contrib >= %{wx_version}

%description
Alien::wxWidgets provides information about a local wxWidgets installation

# Provide perl-specific find-{provides,requires}.
%define __find_provides /usr/lib/rpm/find-provides.perl
%define __find_requires /usr/lib/rpm/find-requires.perl

%prep
%setup -q -n Alien-wxWidgets-%{full_ver}
# %patch

%build
# need this for perl 5.8.0 (RH 8.0, for example)
eval `perl '-V:prefix'`
CFLAGS="$RPM_OPT_FLAGS" perl Build.PL --no-build_wx %{makefile_flags} PREFIX=$RPM_BUILD_ROOT$prefix
./Build
if test "$DISPLAY" != "" ; then
    ./Build test
fi

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
eval `perl '-V:prefix'`
./Build destdir=$RPM_BUILD_ROOT install

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT ! \( -name '.packlist' -o -name 'perllocal.pod' \) \
		     \( -path '*/Alien*' -o -path '*/build*' \) \
                     \( \( -type f -printf '/%%P\n' \) \
                     -o \( -type d -printf '%%%%dir /%%P\n' \) \) |
                    sort -r > Alien-wxWidgets-filelist
# some versions of RPM complain about installed but unpacked files.
find $RPM_BUILD_ROOT \( -name '.packlist' -o -name 'perllocal.pod' \) |
                    xargs rm -f

if [ "$(cat Alien-wxWidgets-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f Alien-wxWidgets-filelist
%defattr(-,root,root)
%doc README.txt Changes

%changelog
