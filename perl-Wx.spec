# RPM spec file for wxPerl

%define blr /var/tmp/perl-Wx-buildroot/
%define ver <% $ver %>
%define full_ver <% $full_ver %>
%define rel <% $release %>
%define wx_version <% $wxgtk_version %>
%define makefile_flags <% $makefile_flags %>

Summary: wxPerl - Perl bindings for wxWindows 
Name: perl-Wx
Version: %{full_ver}
Release: %{rel}
License: This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
Group: # 
Source: http://prdownload.sourceforge.net/wxperl/Wx-%{full_ver}.tar.gz
# Patch: Wx-0.08.patch
Url: http://wxperl.sourceforge.net/
BuildRoot: %{blr}
BuildRequires: perl >= 5.006 , wxGTK-devel >= %{wx_version}, perl-Alien-wxWidgets >= 0.25
Requires: wxGTK >= %{wx_version}

%description
wxPerl is a Perl module wrapping the awesome wxWindows library
for cross-platform GUI developement.

# Provide perl-specific find-{provides,requires}.
%define __find_provides /usr/lib/rpm/find-provides.perl
%define __find_requires /usr/lib/rpm/find-requires.perl

%prep
%setup -q -n Wx-%{full_ver}
# %patch

%build
# need this for perl 5.8.0 (RH 8.0, for example)
eval `perl '-V:prefix'`
CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL --wx-unicode %{makefile_flags} PREFIX=$RPM_BUILD_ROOT$prefix
make
if test "$DISPLAY" != "" ; then
    make test
fi

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
eval `perl '-V:prefix'`
make PREFIX=$RPM_BUILD_ROOT$prefix install

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT ! \( -name '.packlist' -o -name 'perllocal.pod' \) \
		     \( -path '*/Wx*' -o -path '*/build*' \
                        -o -path '*/wx_*' \) \
                     \( \( -type f -printf '/%%P\n' \) \
                     -o \( -type d -printf '%%%%dir /%%P\n' \) \) |
                    sort -r > Wx-filelist
# some versions of RPM complain about installed but unpacked files.
find $RPM_BUILD_ROOT \( -name '.packlist' -o -name 'perllocal.pod' \) |
                    xargs rm -f

if [ "$(cat Wx-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f Wx-filelist
%defattr(-,root,root)
%doc README.txt docs/todo.txt Changes

%changelog
