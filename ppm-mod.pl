#!/usr/bin/perl -w

use strict;
use File::Path qw(mkpath rmtree);

BEGIN { $DistConfig::distrib = 'none' }

sub check_file($);

use FindBin;
use lib "$FindBin::RealBin/lib";
use File::Basename qw(basename);
use DistConfig;
use DistUtils;
use Config;
use Wx;

my $package_src = shift || '';

check_file( $package_src );

my $package_directory = basename( $package_src );
$package_directory =~ s/\.(tar\.gz|zip|tgz)$//;
my $package_base = $package_directory; $package_base =~ s/\-[\d\.]+$//;
my $destination_dir = catdir( $FindBin::RealBin, '..', 'modules' );

my $wx_version = join '.',
                 map { eval "$_ + 0" }
                 ( ( Wx::wxVERSION() =~ m/(\d+)\.(\d{3})?(\d{3})?/ ), 0, 0, 0 )
                 [0 .. 2];
my $wxperl_version = Wx->VERSION;
my $package_build = catdir( $temp_dir, $package_directory );
my $package_ppm_suffix = 'win32'
                      . ( Wx::wxUNICODE() ? '-u' : '' )
                      . "-$Config{version}";
my $package_ppd = "${package_base}.ppd";
my $package_ppm = "${package_base}-ppm.tar.gz";
my $package_ppm_archive = "${package_directory}-" .
                "wxmsw${wx_version}-${package_ppm_suffix}.zip";

check_files();
package_source();
package_build();
package_ppm();

#FIXME
# sanitize path!

sub check_file($) {
  die "File not found '$_[0]'" unless -f $_[0];
}

sub check_files {
  check_file $package_src ;
}

####################################
# build package
###################################
sub package_source {
  rmtree $package_build;
  mkpath $package_build;
  my_chdir catdir( $package_build, updir() );
  extract( $package_src );
}

sub package_build {
#  $ENV{WXDIR} = $wxmsw_build;
#  $ENV{WXWIN} = $wxmsw_build;
#  $ENV{PATH} = catdir( $wxmsw_build, 'lib' ) . ';' . $ENV{PATH};
#  my $uc = $wxperl_unicode ? ' --unicode' : ' ';
  my_chdir $package_build;
  my_system "perl -MConfig_m Makefile.PL";
  my_system 'dmake test';
}

use Config;

sub package_ppm {
  my_chdir $package_build;

  my_system 'dmake ppd';
  my_system "tar cf - blib | gzip -9 > $package_ppm";
  # fix archive name
  for my $data ( [ $package_ppd, $package_ppm ] ) {
      my( $ppd, $pack ) = @$data;
      my_system qq{perl -i.bak -p -e "s#<CODEBASE\\s+HREF=\\"\S*\\"\\s+/>#<CODEBASE HREF=\\"${pack}\\" />#;" $ppd};
  }
  my_system "zip -0 $destination_dir/${package_ppm_archive} $package_ppm $package_ppd";
}

exit 0;

# local variables:
# mode: cperl
# end:
