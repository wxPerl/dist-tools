#
# This spec file was automatically generated by cpan2rpm v2.019
# For more information please visit: http://perl.arix.com/
#
%define pkgname cpan2rpm
%define filelist %{pkgname}-%{version}-filelist
%define NVR %{pkgname}-%{version}-%{release}
%define maketest 1
name:	cpan2rpm
summary:	cpan2rpm - A Perl module packager
version:	2.019
release:	1
vendor:	Erick Calder <ecalder@cpan.org>
packager:	Arix International <cpan2rpm@arix.com>
license:	Artistic
group:	Applications/CPAN
url:	http://www.cpan.org
buildroot:	%{_tmppath}/%{name}-%{version}-%(id -u -n)
buildarch:	noarch
requires:  %([ `rpm -q rpm --qf %%{version}|awk -F . '{print $1}'` -gt 3 ] && echo rpm-build || echo rpm)
source: cpan2rpm-2.019.tar.gz
%description
This script generates an RPM package from a Perl module.  It uses the standard RPM file structure and creates a spec file, a source RPM, and a binary, leaving these in their respective directories.
The script can operate on local files, directories, urls and CPAN module names.  Install this package if you want to create RPMs out of Perl modules.
#
# This package was automatically generated with the cpan2rpm
# utility.  To get this software or for more information
# please visit: http://perl.arix.com/
#
%prep
%setup -q -n %{pkgname}-%{version} 
chmod -R u+w %{_builddir}/%{pkgname}-%{version}
%build
CFLAGS="$RPM_OPT_FLAGS"
%{__perl} Makefile.PL `%{__perl} -MExtUtils::MakeMaker -e ' print qq|PREFIX=%{buildroot}%{_prefix}| if \$ExtUtils::MakeMaker::VERSION =~ /5\.9[1-6]|6\.0[0-5]/ '`
%{__make} 
%if %maketest
%{__make} test
%endif
%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
%{makeinstall} `%{__perl} -MExtUtils::MakeMaker -e ' print \$ExtUtils::MakeMaker::VERSION <= 6.05 ? qq|PREFIX=%{buildroot}%{_prefix}| : qq|DESTDIR=%{buildroot}| '`
[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress
# SuSE Linux
if [ -e /etc/SuSE-release ]; then
%{__mkdir_p} %{buildroot}/var/adm/perl-modules
%{__cat} `find %{buildroot} -name "perllocal.pod"`  \
| %{__sed} -e s+%{buildroot}++g                 \
> %{buildroot}/var/adm/perl-modules/%{name}
fi
# remove special files
find %{buildroot} -name "perllocal.pod" \
-o -name ".packlist"                \
-o -name "*.bs"                     \
|xargs -i rm -f {}
# no empty directories
find %{buildroot}%{_prefix}             \
-type d -depth                      \
-exec rmdir {} \; 2>/dev/null
%{__perl} -MFile::Find -le '
find({ wanted => \&wanted, no_chdir => 1}, "%{buildroot}");
print "%defattr(-,root,root)";
print "%doc perl.req.patch Changes README.redhat6 README";
for my $x (sort @dirs, @files) {
push @ret, $x unless indirs($x);
}
print join "\n", sort @ret;
sub wanted {
return if /auto$/;
local $_ = $File::Find::name;
my $f = $_; s|^%{buildroot}||;
return unless length;
return $files[@files] = $_ if -f $f;
$d = $_;
/\Q$d\E/ && return for reverse sort @INC;
$d =~ /\Q$_\E/ && return
for qw|/etc %_prefix/man %_prefix/bin %_prefix/share|;
$dirs[@dirs] = $_;
}
sub indirs {
my $x = shift;
$x =~ /^\Q$_\E\// && $x ne $_ && return 1 for @dirs;
}
' > %filelist
[ -z %filelist ] && {
echo "ERROR: empty %files listing"
exit -1
}
grep -rsl '^#!.*perl' perl.req.patch Changes README.redhat6 README |
grep -v '.bak$' |xargs --no-run-if-empty \
%__perl -MExtUtils::MakeMaker -e 'MY->fixin(@ARGV)'
%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
%files -f %filelist
%changelog
* Mon Jun 2 2003 ekkis@beowulf
- Initial build.
