#!/usr/bin/perl -w

use strict;
use File::Path qw(mkpath rmtree);

use FindBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use Config;

my $wxmsw_build = catdir( $temp_dir, 'wxMSW' );
my $wxperl_build = catdir( $temp_dir, $wxperl_directory );
my $wxperl_ppm_suffix = 'win32'
                      . ( $wxperl_unicode ? '-u' : '' )
                      . "-$Config{version}";
my $wxperl_ppd = "Wx-${wxperl_version}.ppd";
my $wxperl_ppm = "wxPerl-${wxperl_version}-" .
                 "wx-${wxwin_version}-${wxperl_ppm_suffix}.tar.gz";
my $wxperl_ppm_archive = "Wx-${wxperl_version}-" .
          "wxmsw${wxwin_version}-${wxperl_ppm_suffix}.zip";
my $wxperl_dev_ppd = "Wx-dev-${wxperl_version}.ppd";
my $wxperl_dev_ppm = "wxPerl-dev-${wxperl_version}-" .
                 "wx-${wxwin_version}-${wxperl_ppm_suffix}.tar.gz";
my $wxperl_dev_ppm_archive = "Wx-dev-${wxperl_version}-" .
          "wxmsw${wxwin_version}-${wxperl_ppm_suffix}.zip";

check_files();
unless( $ENV{NO_BUILD_WX} ) {
    wxwindows_source();
    wxwindows_dll();
}
wxperl_source();
wxperl_build();
wxperl_ppm();

#FIXME
# sanitize path!

sub check_file($) {
  die "File not found '$_[0]'" unless -f $_[0];
}

sub check_files {
  check_file $wxmsw_src;
  foreach my $i ( @wxmsw_patches ) {
    check_file $i;
  }
  check_file $wxperl_src;
}

####################################
# unpack wxWindows & apply patches
####################################
sub wxwindows_source {
  rmtree $wxmsw_build;
  mkpath $wxmsw_build;
  my_chdir $wxmsw_build;
  my $wad = $wxmsw_directory;

  if( length $wad ) {
    extract( $wxmsw_src, "$wad/contrib/*", "$wad/src/*", "$wad/lib/*",
             "$wad/include/*" );
    extract( $wxmsw_src, "$wad/art/*" ) if is_wx23;
    my_system "mv $wad/* .";
    my_system "rmdir $wad";
  } else {
    extract( $wxmsw_src, "contrib/*", "src/*", "lib/*", "include/*" );
    extract( $wxmsw_src, "art/*" ) if is_wx23;
  }

  foreach my $i ( @wxmsw_archives ) { extract( $i, "*" ) }
  my_system "cp -f include/wx/msw/setup0.h include/wx/msw/setup.h"
    if -f "include/wx/msw/setup0.h";
  foreach my $i ( @wxmsw_patches ) {
    my_system "cat $i | patch -b -p0";
  }
}

####################################
# build wxWindows
####################################
sub wxwindows_dll {
  $ENV{WXDIR} = $wxmsw_build;
  $ENV{WXWIN} = $wxmsw_build;
  my $uc = $wxperl_unicode ? ' UNICODE=1' : ' UNICODE=0';
  my_chdir catdir( $wxmsw_build, 'src', 'msw' );
  my_system "make -f makefile.g95 all$uc WXMAKINGDLL=1 FINAL=1";
  if( is_wx23 ) {
    my_chdir catdir( $wxmsw_build, 'contrib', 'src', 'xrc' );
    my_system "make -f makefile.g95 all$uc WXUSINGDLL=1 FINAL=1";
  }
  my_chdir catdir( $wxmsw_build, 'contrib', 'src', 'stc' );
  my_system "make -f makefile.g95 all$uc WXUSINGDLL=1 FINAL=1";
}

####################################
# build wxperl
###################################
sub wxperl_source {
  rmtree $wxperl_build;
  mkpath $wxperl_build;
  my_chdir catdir( $wxperl_build, updir() );
  extract( $wxperl_src );
}

sub wxperl_build {
  $ENV{WXDIR} = $wxmsw_build;
  $ENV{WXWIN} = $wxmsw_build;
  $ENV{PATH} = catdir( $wxmsw_build, 'lib' ) . ';' . $ENV{PATH};
  my $uc = $wxperl_unicode ? ' --unicode' : ' ';
  my_chdir $wxperl_build;
  my_system "perl -MConfig_m Makefile.PL$uc ";
  my_system 'dmake test';
}

use Config;

sub wxperl_ppm {
  my_chdir $wxperl_build;

  my_system 'dmake ppmdist';
  # fix archive name
  for my $data ( [ $wxperl_ppd, $wxperl_ppm ],
                 [ $wxperl_dev_ppd, $wxperl_dev_ppm ] ) {
      my( $ppd, $pack ) = @$data;
      my_system qq{perl -i.bak -p -e "s#<CODEBASE\\s+HREF=\\"\\S+\\"\\s+/>#<CODEBASE HREF=\\"${pack}\\" />#;" $ppd};
  }
  my_system "mv Wx-${wxperl_version}-ppm.tar.gz $wxperl_ppm";
  my_system "cp -f $data_dir/README.txt .";
  my_system "zip -0 $distribution_dir/${wxperl_ppm_archive} $wxperl_ppm $wxperl_ppd README.txt";
  my_system "mv Wx-dev-${wxperl_version}-ppm.tar.gz $wxperl_dev_ppm";
  my_system "cp -f $data_dir/README.txt .";
  my_system "zip -0 $distribution_dir/${wxperl_dev_ppm_archive} $wxperl_dev_ppm $wxperl_dev_ppd README.txt";
}

exit 0;

# local variables:
# mode: cperl
# end:

