my $rpms_72 = <<RPMS;
setup filesystem basesystem
sash
glibc-common glibc
bash mktemp termcap libtermcap 
--nodeps info
gawk fileutils diffutils textutils popt bzip2 bzip2-libs zlib db3 gzip unzip
shadow-utils dev sed
tar make grep patch file findutils
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
$chroot = '/home/mbarbon/chroot/rh72';
my @rpmpath_72 = ( '/scratch/redhat/rh72' );
$rpms = $rpms_72;
@rpmpath = @rpmpath_72;
