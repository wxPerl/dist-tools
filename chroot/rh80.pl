my $rpms_80 = <<RPMS;
setup filesystem basesystem
--nodeps glibc-common
glibc
bash mktemp termcap libtermcap
--nodeps info
gawk pcre grep libattr libacl fileutils textutils popt bzip2 bzip2-libs zlib
--nodeps ncurses
less
--nodeps gzip unzip
shadow-utils dev sed diffutils
tar make patch file findutils
--nodeps sh-utils pam
gdbm db4
--nodeps perl-Filter perl
libelf rpm rpm-build
--nodeps glibc-kernheaders
libgcc binutils cpp glibc-devel libstdc++ libstdc++-devel bison flex
--nodeps gcc gcc-c++
XFree86-devel expat fontconfig XFree86-Mesa-libGL XFree86-libs freetype
gtk+-devel gtk+ glib-devel glib zlib-devel
libpng libpng-devel libjpeg libjpeg-devel libtiff libtiff-devel
RPMS
$chroot = '/home/mbarbon/chroot/rh80';
my @rpmpath_80 = ( '/cdrom/RedHat/RPMS', '/scratch/redhat/rh80/cd2' );
$rpms = $rpms_80;
@rpmpath = @rpmpath_80;
