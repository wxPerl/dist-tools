package DistConfig;

use strict;

#####
use vars '$distrib';
$distrib = shift @ARGV unless $distrib;
#####

use DistUtils qw(catfile catdir);

require Exporter;
use FindBin;
use Config::IniFiles;

use base qw(Exporter);

use vars qw(@EXPORT);
@EXPORT = qw($wxperl_src $wxperl_version $wxperl_directory $wxmsw_src $temp_dir
             $distribution_dir $data_dir $wxwin_version $contrib_makefiles
             @wxmsw_patches $wxperl_doc_dir $rh_chroot_dir $rh_rpm_spec
             $chroot_user $chroot_group $chroot_home $deb_chroot_dir
             @wxmsw_archives $wxperl_number $wxperl_static $wxgtk_archive
             $wxgtk_src $wxwin_number $wxgtk_directory $wxmsw_directory
             $rh_ccache $deb_ccache $wxperl_unicode);

use vars  qw($wxperl_src $wxperl_version $wxperl_directory $wxmsw_src $temp_dir
             $distribution_dir $data_dir $wxwin_version $contrib_makefiles
             @wxmsw_patches $wxperl_doc_dir $rh_chroot_dir $rh_rpm_spec
             $chroot_user $chroot_group $chroot_home $deb_chroot_dir
             @wxmsw_archives $wxperl_number $wxperl_static $wxgtk_archive
             $wxgtk_src $wxwin_number $wxgtk_directory $wxmsw_directory
             $rh_ccache $deb_ccache $wxperl_unicode);

my $ini = new Config::IniFiles( -file => catfile( $FindBin::RealBin,
                                                  'config.ini' ) );
sub v($$) { $ini->val( $_[0], $_[1] ) }

die "Specified section '$distrib' does not exist"
  unless $ini->SectionExists( $distrib );

my $msw = v( $distrib, 'wxmsw' );
my $gtk = v( $distrib, 'wxgtk' );

my $wx_data_dir = v( 'Directories', "data-$^O" );

$temp_dir = v( 'Directories', "temp-$^O" );
$distribution_dir = v( 'Directories', "dist-$^O" );

$rh_chroot_dir = v( 'RedHat', 'chroot' );
$rh_ccache = v( 'RedHat', 'ccache' );
$deb_chroot_dir = v( 'Debian', 'chroot' );
$deb_ccache = v( 'Debian', 'ccache' );

my $my_wxperl_version = v( $distrib, 'wxperl_version' );
( $wxperl_number = $my_wxperl_version ) =~ s/[^\d\.].*$//;
$wxperl_version = $my_wxperl_version;
$wxperl_directory = "Wx-${wxperl_number}";

$wxperl_doc_dir = v( v( $distrib, 'docs' ), 'doc_dir' );
$wxperl_src = catfile( $wx_data_dir, "Wx-${wxperl_version}.tar.gz" );
$wxperl_unicode = v( $distrib, 'unicode' ) || 0;
$wxwin_version = v( $distrib, 'wxwin_version' );
( $wxwin_number = $wxwin_version ) =~ s/[^\d\.].*$//;

$wxwin_number =~ m/^(\d+\.\d+)/; my $td_number = $1;
$contrib_makefiles = catfile( $wx_data_dir, "makefiles-${td_number}.tar.gz" );

$wxmsw_src = catfile( $wx_data_dir, v( $msw, 'archive' ) );
$wxmsw_directory = v( $msw, 'directory' ) || '';
@wxmsw_patches = map { $_ ? catfile( $wx_data_dir, $_ ) : () }
  v( $msw, 'patches' );
@wxmsw_archives = map { $_ ? catfile( $wx_data_dir, $_ ) : () }
  v( $msw, 'other' );

$wxperl_static = v( $gtk, 'static' ) || 0;
$wxgtk_archive = v( $gtk, 'archive' ) || '';
$wxgtk_src = length( $wxgtk_archive ) ?
  catfile( $wx_data_dir, $wxgtk_archive ) : '';
$wxgtk_directory = v( $gtk, 'directory' ) || '';

$chroot_user = v( 'RedHat', 'user' );
$chroot_group = v( 'RedHat', 'group' );
$chroot_home = v( 'RedHat', 'home' );

$data_dir = $FindBin::RealBin;

$rh_rpm_spec = catfile( $data_dir,
                        v( 'RedHat', 'package', ) . '.spec' );

use File::Path qw(mkpath);

mkpath $temp_dir;
mkpath $distribution_dir;

1;

# local variables:
# mode: cperl
# end:

