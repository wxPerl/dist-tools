my $rpms_71 = <<RPMS;
setup filesystem basesystem
sash
glibc-common glibc
bash mktemp termcap libtermcap
--nodeps info
gawk fileutils textutils diffutils popt bzip2 zlib db3 gzip
shadow-utils dev
tar make grep patch sed file findutils
--nodeps sh-utils pam
gdbm db2 db1 perl
rpm rpm-build
--nodeps kernel-headers
gcc binutils cpp glibc-devel gcc-c++ libstdc++ libstdc++-devel bison flex
XFree86-devel XFree86-libs freetype
gtk+-devel gtk+ glib-devel glib zlib-devel
libpng libpng-devel libjpeg libjpeg-devel libtiff libtiff-devel
--nodeps Mesa Mesa-devel
RPMS
$chroot = '/home/mbarbon/chroot/rh71';
my @rpmpath_71 = ( '/cdrom/rh71/RPMS' );
$rpms = $rpms_71;
@rpmpath = @rpmpath_71;
