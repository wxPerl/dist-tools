my $rpms_73 = <<RPMS;
setup filesystem basesystem
sash
--nodeps glibc-common glibc
bash mktemp termcap libtermcap 
--nodeps info
gawk fileutils textutils popt bzip2 bzip2-libs zlib db3 ncurses less gzip unzip
shadow-utils dev sed diffutils
tar make pcre grep patch file findutils
--nodeps sh-utils pam
gdbm db2 db1 perl
rpm rpm-build
--nodeps glibc-kernheaders
gcc binutils cpp glibc-devel gcc-c++ libstdc++ libstdc++-devel bison flex
XFree86-devel XFree86-libs freetype
gtk+-devel gtk+ glib-devel glib zlib-devel
libpng libpng-devel libjpeg libjpeg-devel libtiff libtiff-devel
RPMS
$chroot = '/home/mbarbon/chroot/rh73';
my @rpmpath_73 = ( '/scratch/redhat/rh73' );
$rpms = $rpms_73;
@rpmpath = @rpmpath_73;
