#!/usr/bin/perl -w

use strict;

BEGIN { $DistConfig::distrib = 'none' }

use FindBin;
use lib $FindBin::RealBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use DistScripts;
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename);
use Text::Template;

my $package_src = shift;
my $home = catdir( $rh_chroot_dir, $chroot_home );
my $destination_dir = catdir( $FindBin::RealBin, '..', 'modules' );

sub check_dir {
  die "Directory not found '$_[0]'" unless -d $_[0];
}

check_dir( $rh_chroot_dir );
check_dir( $home );

# setup buildarea
my $buildarea = catdir( $home, 'buildarea' );
rmtree( $buildarea ) if -d $buildarea;
mkpath( $buildarea ) or die "mkpath '$buildarea'"
  unless -d $buildarea;
foreach my $i ( qw(RPMS RPMS SRPMS SOURCES BUILD SPECS) ) {
  my $dir = catdir( $buildarea, $i );
  mkdir( $dir, 0755 ) or die "mkpath '$dir'"
    unless -d $dir;
}

# copy files
my $src_base = basename( $package_src );

my_system "cp $package_src $home";
my_system "cp -R cpan2rpm $home";

# ccache support
my $ccache = eval( $rh_ccache ? ccache_vars : '' );
#my $functions = common_functions;

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
# \$functions

export DISPLAY=192.168.9.2:0.0

perl cpan2rpm/cpan2rpm $src_base

exit 0
EOT
close OUT;

# build
my $ch_arg = basename( $rh_chroot_dir );
my_system "sudo do_chroot $ch_arg '/bin/sh' '$chroot_home/buildrpm'";

my $bin_rpm = ( glob( catfile( $buildarea, 'RPMS', '*', '*.rpm' ) ) )[0];
my $src_rpm = ( glob( catfile( $buildarea, 'SRPMS', '*.rpm' ) ) )[0];

die "something went wrong while building"
  unless defined( $bin_rpm ) && defined( $src_rpm ) &&
         -f $bin_rpm && -f $src_rpm;

my $src_final_rpm = basename( $src_rpm );
my $bin_final_rpm = basename( $bin_rpm );
$bin_final_rpm =~ s/(\.[^\.]+\.rpm)$/_wxgtk${wxwin_version}${1}/;

my_system "cp $src_rpm $destination_dir/$src_final_rpm";
my_system "cp $bin_rpm $destination_dir/$bin_final_rpm";

# Local variables: #
# mode: cperl #
# End: #
