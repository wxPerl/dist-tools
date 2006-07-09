#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils;
use File::Spec::Functions qw(catdir catfile);
use File::Path qw(mkpath rmtree);

my( @configs ) = ( @ARGV );
my $dc = DistConfig->new( $configs[0], '' );

my $wxperl_version = $dc->wxperl_version;
my $wxperl_src = $dc->wxperl_src;
my $distribution_dir = $dc->distribution_dir;
my $temp_dir = $dc->temp_dir;
my $wxperl_directory = $dc->wxperl_directory;
my $wxperl_samples = "wxPerl-${wxperl_version}-samples.zip";
my $wxwin_version = $dc->wxwin_version;
my $wxperl_doc_dir = $dc->wxperl_doc_dir;

my $wxperl_doc_prefix = "wxPerl-${wxperl_version}-" .
                        "wx-${wxwin_version}-docs";
my $hhc = 'c:\Programmi\Devel\HHWorkshop\hhc.exe';

############################
# setup the environment
############################

my $html_build  = catdir( $temp_dir, 'html' );
my $tex_build   = catdir( $temp_dir, 'tex' );

my $html_file  = catfile( $html_build, 'manua.htm' );
my $tex_file   = catfile( $tex_build, 'manual.tex' );
my $macro_file = catfile( $tex_build, 'tex2rtf.ini' );

rmtree $tex_build if -d $tex_build;
rmtree $html_build if -d $html_build;
mkpath $html_build;
mkpath $tex_build;

make_tex();
make_html();
make_tex_zip();
make_html_zip();
make_chm();

sub make_tex {
  foreach my $i ( qw(gif ini sty inc tex bib bmp dot eps txt css) ) {
    my $glob = catfile( $wxperl_doc_dir, "*.$i" );
    my $cmd = $i eq 'tex' ? 'perl copytex.pl' : 'cp';
    $i =~ 'css' ?    system( "$cmd $glob $tex_build" )
                : my_system( "$cmd $glob $tex_build" );
  }
}

sub make_html {
  ############################
  # invoke Tex2RTF
  ############################

  # need to chdir, since tex2RTF puts *.con files in the
  # current directory...
  my_chdir $html_build;
  my_system( 'tex2rtf', $tex_file, $html_file, '-macros', $macro_file,
             '-html', '-twice' );#, '-checkcurleybraces' );
  my $glob = catfile( $tex_build, "*.gif" );
  my_system( "cp $glob ." );
}

sub make_chm {
  my $chmfile = catfile( $distribution_dir, "${wxperl_doc_prefix}-chm.chm" );

  my_chdir $html_build;
  die "no file 'manua.hhp'" unless -f 'manua.hhp';
  if( -f $hhc ) {
    system( "$hhc manua.hhp" );
    die "no file 'manua.chm'" unless -f 'manua.chm';
    my_system( "mv manua.chm $chmfile" );
  }
}

sub make_tex_zip {
  my $zipfile = catfile( $distribution_dir, "${wxperl_doc_prefix}-tex.zip" );

  my_chdir $tex_build;
  my_system( "zip -q -9 $zipfile *" );
}

sub make_html_zip {
  #
  # clean the directory
  #
  my $zipfile = catfile( $distribution_dir, "${wxperl_doc_prefix}-html.zip" );
  my_chdir $html_build;
  foreach my $i ( qw(con ref) ) {
    my_system( "rm -f *.$i" );
  }

  my_system( "zip -q -9 $zipfile *" );
}

exit 0;

# local variables:
# mode: cperl
# end:
