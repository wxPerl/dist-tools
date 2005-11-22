package DistConfig;

use strict;
use warnings;

require Exporter;
use FindBin;
use Config::IniFiles;
use File::Path qw(mkpath);
use File::Spec::Functions qw(canonpath catfile catdir);

my $ini = new Config::IniFiles( -file => catfile( $FindBin::RealBin,
                                                  'config.ini' ) );
sub v($$) { $ini->val( $_[0], $_[1] ) }

sub new {
    my( $class, $distrib, $host ) = @_;
    my $self = bless { }, __PACKAGE__;

    die "Specified section '$distrib' does not exist"
      unless $ini->SectionExists( $distrib );

    my $msw = v( $distrib, 'wxmsw' );
    my $gtk = v( $distrib, 'wxgtk' );
    my $mac = v( $distrib, 'wxmac' );

    my $wx_data_dir = v( 'Directories', "data-$^O" );

    my $temp_dir = v( 'Directories', "temp-$^O" );
    my $distribution_dir = v( 'Directories', "dist-$^O" );

    my $ccache = v( $host, 'ccache' );
    my $xhost = v( $host, 'xhost' );

    my $my_wxperl_version = v( $distrib, 'wxperl_version' );
    ( my $wxperl_number = $my_wxperl_version ) =~ s/[^\d\.].*$//;
    my $wxperl_version = $my_wxperl_version;
    my $wxperl_directory = "Wx-${wxperl_number}";

    my $wxperl_doc_dir = v( v( $distrib, 'docs' ), 'doc_dir' );
    my $wxperl_src = catfile( $wx_data_dir, "Wx-${wxperl_version}.tar.gz" );
    my $wxperl_unicode = v( $distrib, 'unicode' ) || 0;
    my $wxwin_version = v( $distrib, 'wxwin_version' );
    ( my $wxwin_number = $wxwin_version ) =~ s/[^\d\.].*$//;

    $wxwin_number =~ m/^(\d+\.\d+)/; my $td_number = $1;
    my $contrib_makefiles =
      catfile( $wx_data_dir, "makefiles-${td_number}.tar.gz" );

    my $wxmsw_src = catfile( $wx_data_dir, v( $msw, 'archive' ) );
    my $wxmsw_directory = v( $msw, 'directory' ) || '';
    my @wxmsw_patches = map { $_ ? catfile( $wx_data_dir, $_ ) : () }
      v( $msw, 'patches' );
    my @wxmsw_archives = map { $_ ? catfile( $wx_data_dir, $_ ) : () }
      v( $msw, 'other' );

    my $wxgtk_archive = v( $gtk, 'archive' ) || '';
    my $wxgtk_src = length( $wxgtk_archive ) ?
      catfile( $wx_data_dir, $wxgtk_archive ) : '';
    my $wxgtk_directory = v( $gtk, 'directory' ) || '';

    my $wxmac_archive = v( $mac, 'archive' ) || '';
    my $wxmac_src = length( $wxmac_archive ) ?
      catfile( $wx_data_dir, $wxmac_archive ) : '';
    my @wxmac_archives = map { catfile( $wx_data_dir, $_ ) }
                             v( $mac, 'archives' ) if v( $mac, 'archives' );
    my @wxmac_patches = map { $_ ? catfile( $wx_data_dir, $_ ) : () }
      v( $mac, 'patches' );
    my $wxmac_directory = v( $mac, 'directory' ) || '';

    my $remote_user = $host ? v( $host, 'user' ) : '';
    my $remote_group = $host ? v( $host, 'group' ) : '';
    my $remote_home = $host ? v( $host, 'home' ) : '';
    my $remote_host = $host ? v( $host, 'host' ) : '';

    my $data_dir = $FindBin::RealBin;

    my $rpm_spec = v( $host, 'package' ) ?
                       catfile( $data_dir, v( $host, 'package' ) . '.spec' ) :
                       '';

    mkpath $temp_dir;
    mkpath $distribution_dir
;
    @{$self}{qw(wxperl_src wxperl_version wxperl_directory wxmsw_src temp_dir
             distribution_dir data_dir wxwin_version contrib_makefiles
             wxmsw_patches wxperl_doc_dir rpm_spec
             remote_user remote_group remote_home remote_host
             wxmsw_archives wxperl_number wxgtk_archive
             wxgtk_src wxwin_number wxgtk_directory wxmsw_directory
             ccache xhost wxperl_unicode wxmac_src wxmac_patches
             wxmac_directory wxmac_archive wx_data_dir wxmac_archives)} =
        ( $wxperl_src, $wxperl_version, $wxperl_directory, $wxmsw_src, $temp_dir,
          $distribution_dir, $data_dir, $wxwin_version, $contrib_makefiles,
          \@wxmsw_patches, $wxperl_doc_dir, $rpm_spec,
          $remote_user, $remote_group, $remote_home, $remote_host,
          \@wxmsw_archives, $wxperl_number, $wxgtk_archive,
          $wxgtk_src, $wxwin_number, $wxgtk_directory, $wxmsw_directory,
          $ccache, $xhost, $wxperl_unicode, $wxmac_src, \@wxmac_patches,
          $wxmac_directory, $wxmac_archive, $wx_data_dir, \@wxmac_archives,
        );

    return $self;
}

sub get_module_src {
    my $self = shift;

    return canonpath( catfile( catdir( $self->wx_data_dir, '..', 'modules' ),
                               $_[0] ) );
}

our $AUTOLOAD;

sub AUTOLOAD {
    die $AUTOLOAD, ' ', $_[0] unless ref $_[0];
    my $name = $AUTOLOAD; $name =~ s/.*:://;
    return if $name eq 'DESTROY';
    die $name unless exists $_[0]->{$name};

    no strict 'refs';
    *$AUTOLOAD = sub { $_[0]->{$name} };
    goto &$AUTOLOAD;
}

1;

# local variables:
# mode: cperl
# end:

