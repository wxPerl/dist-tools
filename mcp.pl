#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use IO::Handle;
use lib "$FindBin::RealBin/lib";

my( $plat, @configs ) = ( shift @ARGV, @ARGV );

my $module = 'Wx::' . ucfirst $plat;
eval "require $module"; die $@ if $@;

my $driver = $module->new;

foreach my $config ( @configs ) {
    $driver->set_options( config => $config );
    $driver->build_wxwidgets;
    $driver->build_wxperl;
    $driver->package_wxwidgets;
    $driver->package_wxperl;
    $driver->install_wxperl;
    $driver->build_submodules( 'Wx-GLCanvas-0.03.tar.gz',
                               'Wx-ActiveX-0.059901.tar.gz' );
    $driver->make_dist;
}

exit 0;
