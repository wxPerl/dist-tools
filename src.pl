#!/usr/bin/perl -w

use strict;
use File::Path qw(mkpath rmtree);

use FindBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use File::Spec::Functions qw(catdir updir catfile);

my $wxperl_samples = "wxPerl-${wxperl_version}-samples.zip";

# copy source to the release dir...
my_system "cp $wxperl_src $distribution_dir";

# now make the samples' archive
my $wxperl_build = catdir( $temp_dir, $wxperl_directory );
my $wxperl_build_rel = $wxperl_directory;

rmtree $wxperl_build;
mkpath $wxperl_build;
my_chdir catdir( $wxperl_build, updir() );
my_system "gunzip -cd $wxperl_src | tar xvf -";

# create .mo files
foreach my $i ( glob( catfile( $wxperl_build, qw(demo data locale ??) ) ) ) {
  my $po = catfile( $i, 'wxperl_demo.po' );
  my $mo = catfile( $i, 'wxperl_demo.mo' );
  my_system "msgfmt -o $mo $po";
}

my $tmp = catfile( $distribution_dir, $wxperl_samples );
unlink $tmp if -f $tmp;
my_system "zip -9r $distribution_dir/$wxperl_samples " .
  "$wxperl_build_rel/samples $wxperl_build_rel/demo";

# local variables:
# mode: cperl
# end:

