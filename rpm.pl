#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::RealBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use DistScripts;
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename);
use Text::Template;

sub check_dir {
  die "Directory not found '$_[0]'" unless -d $_[0];
}

check_dir( $rh_chroot_dir );
check_dir( catdir( $rh_chroot_dir, $chroot_home ) );

# setup buildarea
my $buildarea = catdir( $rh_chroot_dir, $chroot_home, 'buildarea' );
rmtree( $buildarea ) if -d $buildarea;
mkpath( $buildarea ) or die "mkpath '$buildarea'"
  unless -d $buildarea;
foreach my $i ( qw(RPMS RPMS/i386 SRPMS SOURCES BUILD SPECS) ) {
  my $dir = catdir( $buildarea, $i );
  mkdir( $dir, 0755 ) or die "mkpath '$dir'"
    unless -d $dir;
}

# copy files
my_system "cp $wxperl_src " . catdir( $buildarea, 'SOURCES' );
my_system "cp $wxgtk_src " . catdir( $buildarea, 'SOURCES' )
  if length $wxgtk_src;
my_system "cp $contrib_makefiles " . catdir( $buildarea, 'SOURCES' );

my $makefiles_tgz = basename $contrib_makefiles;
my $got_contrib = 0;

# generate spec file / basic sanity checks
my $out_spec = catdir( $buildarea, 'SPECS' ) . "/" .
  basename( $rh_rpm_spec );
my( $rpm_release, $rpm_arch ) = qw(1 i386);

my $tmpl = Text::Template->new( TYPE => 'FILE',
                                SOURCE => $rh_rpm_spec,
                                DELIMITERS => [ '<%', '%>' ] );

print "Writing '$out_spec'\n";
open OUT, "> $out_spec" or die "unable to open '$out_spec' for output";

my $xxx = "`pwd`/../\$wxgtk_directory";
my $makefile_flags = #'"'.
  ( $wxperl_static ? '--static ' : '' )
  . ( ( $wxwin_number =~ m/^2\.2/ ) ? '--disable-xrc ' : '' )
  . ( $got_contrib ? '' : qq{--extra-cflags="-I${xxx}/contrib/include" --extra-libs="-L${xxx}/lib" } )
  . qq("");
  ;

die "Error while filling template: $Text::Template::ERROR"
  unless $tmpl->fill_in( OUTPUT => \*OUT,
                         HASH => { full_ver => $wxperl_version,
                                   ver => $wxperl_number,
                                   release => $rpm_release,
                                   wxgtk_version => $wxwin_version,
                                   makefile_flags => $makefile_flags,
                                   } );
close OUT;

# ccache support
my $ccache = eval( $rh_ccache ? ccache_vars : '' );
my $functions = common_functions;

# setup
open OUT, "> " . catfile( $rh_chroot_dir, $chroot_home, '.rpmmacros' )
  or die "open";
print OUT "\%_topdir $chroot_home/buildarea\n";
close OUT;

open OUT, "> " .catfile( $rh_chroot_dir, $chroot_home, 'buildrpm' )
  or die "open";
print OUT <<EOT;
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=192.168.9.2:0.0
dname=wxWin
export wxgtk_directory=$wxgtk_directory
SRC=../SOURCES

if test "${wxperl_static}" = "1"; then
    cd buildarea/BUILD
    extract_wx_archive \$SRC/${wxgtk_archive}

    for i in inst inst/\$dname; do
      test -d \$i || mkdir \$i
    done
    cd \$wxgtk_directory
    # now in buildarea/BUILD/wxGTK-xxx
    test -d build || mkdir build
    cd build
    # now in buildarea/BUILD/wxGTK-xxx/build
    sh ../configure --with-gtk --disable-shared --prefix=`pwd`/../../inst/\$dname
    make all install
    cd contrib/src
    # now in buildarea/BUILD/wxGTK-xxx/build/contrib/src
    for i in xrc stc; do
      test -d \$i && cd \$i && make all install && cd ..
    done
    cd ../..
    # now in buildarea/BUILD/wxGTK-xxx/build
    cd ../..
    # now in buildarea/BUILD
    export PATH=`pwd`/inst/\$dname/bin:\$PATH
    # back were we started
    cd ../..
elif test "${got_contrib}" = "0"; then
    cd buildarea/BUILD
    if test "\$wxgtk_directory" = ""; then
        extract_wx_archive \$SRC/${wxgtk_archive} "contrib/*"
    else
        extract_wx_archive \$SRC/${wxgtk_archive} "\$wxgtk_directory/contrib/*"
    fi
    cd \$wxgtk_directory
    mkdir lib
    extract ../\$SRC/$makefiles_tgz
    cd contrib/src
    for i in xrc stc; do
      test -d \$i && ( cd \$i && make -f makefile.unx )
    done

    cd ../../..
    cd ../..
fi

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

rpmbuild -ba buildarea/SPECS/perl-Wx.spec

exit 0
EOT
close OUT;

# rpm names
my $rpm_name = 'perl-Wx';
my $bin_final_rpm = "$rpm_name-$wxperl_version-${rpm_release}_" .
       "wxgtk$wxwin_version.$rpm_arch.rpm";
my $src_final_rpm = "$rpm_name-$wxperl_version-$rpm_release.src.rpm";
my $bin_rpm = catfile( $buildarea, 'RPMS', $rpm_arch,
        "$rpm_name-$wxperl_number-$rpm_release.$rpm_arch.rpm" );
my $src_rpm = catfile( $buildarea, 'SRPMS',
        "$rpm_name-$wxperl_number-$rpm_release.src.rpm" );

# build
my $ch_arg = basename( $rh_chroot_dir );
my_system "sudo do_chroot $ch_arg '/bin/sh' '$chroot_home/buildrpm'";

die "something went wrong while building"
  unless -f $bin_rpm && -f $src_rpm;

my_system "cp $src_rpm $distribution_dir/$src_final_rpm";
my_system "cp $bin_rpm $distribution_dir/$bin_final_rpm";

# Local variables: #
# mode: cperl #
# End: #
