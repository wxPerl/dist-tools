#!/usr/bin/perl -w

use strict;
use File::Spec;

use FindBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename);

# setup buildarea
my $buildarea = catdir( $deb_chroot_dir, $chroot_home, 'buildarea' );

rmtree( $buildarea ) if -d $buildarea;
mkpath $buildarea or die "mkpath '$buildarea'"
  unless -d $buildarea;

# ccache support
my $ccache = '';
if( $rh_ccache ) {
  $ccache = <<EOT;
export CCACHE_DIR=$rh_ccache
export CCACHE_NOLINK=1
export CC='ccache cc'
export CXX='ccache c++'
EOT
}

# copy files
my_system "cp $wxperl_src $buildarea";
my_system "cp -r $data_dir/debian $buildarea";
if( $wxperl_static ) {
  my_system "cp $wxgtk_src $buildarea";
}

# extract release from changelog file
my( $deb_release, $deb_arch );
$deb_arch = 'i386';
open IN, "< $data_dir/debian/changelog" or die "open";
my $rel = '';
while( <IN> ) {
  m/^\s*\S+\s+\(([^\)]+)\)/ and $rel = $1 and last;
}
close IN;
die "Unable to parse changelog" unless length $rel;
$rel =~ m/-(\d+)/; $deb_release = $1;
die "Unable to parse changelog" unless length $deb_release;

# deb names
my $wxgtk_deb_ver = $wxwin_version; $wxgtk_deb_ver =~ s/\.\d+[^.]*$//;
my $bin_deb = "libwx-perl-wxgtk${wxgtk_deb_ver}_${wxperl_number}-" .
  "${deb_release}_${deb_arch}.deb";
my $bin_deb_final = "libwx-perl-wxgtk${wxgtk_deb_ver}_${wxperl_version}-" .
  "${deb_release}_${deb_arch}.deb";
my $src_dir = "libwx-perl-${wxperl_number}";
my $src_base = "libwx-perl_${wxperl_number}";
my $src_diff = "$src_base-${deb_release}.diff.gz";
my $src_dsc = "$src_base-${deb_release}.dsc";
my $src_tgz = "$src_base.orig.tar.gz";
my $src_tgz_all = "$src_base-${deb_release}.deb.src.tar.gz";

# create build script file
open OUT, "> " .catfile( $deb_chroot_dir, $chroot_home, 'builddeb' )
  or die "open";
print OUT <<EOT;
#!/bin/sh

set -e
set -x

$ccache

function extract {
    case "\$1" in
        *.zip) unzip \$1 ;;
        *.tar.gz) gzip -cd \$1 | tar xvf - ;;
        *.tar.bz2) bzip2 -cd \$1 | tar xvf - ;;
    esac
}

export DISPLAY=192.168.9.2:0.0
dname=wxWin
wxgtk_directory=$wxgtk_directory

if test "${wxperl_static}" = "1"; then
  if test -f buildarea/${wxgtk_archive}; then
    cd buildarea
    # now in buildarea
    if test "\$wxgtk_directory" != ""; then
      extract ${wxgtk_archive}
    else
      wxgtk_directory=myDIR
      mkdir \$wxgtk_directory
      cd \$wxgtk_directory
      extract ../${wxgtk_archive}
      cd ..
    fi
    for i in inst inst/wxGTK; do
      test -d \$i || mkdir \$i
    done
    cd \$wxgtk_directory
    # now in buildarea/wxGTK-xxx
    test -d build || mkdir build
    cd build
    # now in buildarea/wxGTK-xxx/build
    sh ../configure --with-gtk --disable-shared --prefix=`pwd`/../../inst/wxGTK
    make all install
    cd contrib/src
    # now in buildarea/BUILD/wxGTK-xxx/build/contrib/src
    for i in xrc stc; do
      test -d \$i && cd \$i && make all install && cd ..
    done
    cd ../..
    # now in buildarea/wxGTK-xxx/build
    cd ../..
    # now in buildarea
    export PATH=`pwd`/inst/wxGTK/bin:\$PATH
    # back were we started
    cd ..
  else
    echo "wxGTK-${wxwin_version}.tar.gz not found"
    exit 1
  fi
fi

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

cd buildarea

zcat Wx-${wxperl_version}.tar.gz | tar -x -f -
mv Wx-${wxperl_number} $src_dir
mv Wx-${wxperl_version}.tar.gz $src_tgz
cp -r debian $src_dir
chmod +x $src_dir/debian/rules

# now build it!
dpkg-source -b $src_dir $src_tgz
cd $src_dir
fakeroot debian/rules binary-arch STATIC=${wxperl_static}
EOT
close OUT;

# build source/binary packages
my $ch_arg = basename( $deb_chroot_dir );
my_system "sudo do_chroot $ch_arg '/bin/sh' '$chroot_home/builddeb'";

rmtree catdir( $distribution_dir, 'debian' );
mkpath catdir( $distribution_dir, 'debian' ) or die "mkpath";
my_chdir $buildarea;

# now copy files to the right location

die "something went wrong while building"
  unless -f $bin_deb && -f $src_tgz && -f $src_diff && -f $src_dsc;

my_system "cp $bin_deb $distribution_dir/$bin_deb_final";
my_system "cp $src_tgz $distribution_dir/debian";
my_system "cp $src_diff $distribution_dir/debian";
my_system "cp $src_dsc $distribution_dir/debian";
my_chdir catdir( $distribution_dir, 'debian' );
my_system "tar -c -v -f - $src_tgz $src_diff $src_dsc | gzip -9 > ../$src_tgz_all";

# Local variables: #
# mode: cperl #
# End: #
