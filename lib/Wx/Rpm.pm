package Wx::Rpm;

use strict;
use warnings;
use base 'Wx::Base';
use DistUtils;
use DistScripts;
use DistConfig ();
use File::Basename qw(basename dirname);
use Text::Template;
use File::Temp;

sub catfile { File::Spec::Unix->catfile( @_ ) }
sub catdir { File::Spec::Unix->catdir( @_ ) }

sub set_options {
    my( $self, %args ) = @_;

    my $dc = DistConfig->new( $args{config}, 'RedHat' );

    $self->{distconfig} = $dc;

    my $remote_home = $dc->remote_home;

    $self->_put_string( "\%_topdir $remote_home/buildarea\n", '.rpmmacros' );

    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $ccache = eval( $dc->ccache ? ccache_vars : '' );
    my $buildarea = catdir( $dc->remote_home, 'buildarea' );
    my $wxperl_version = $dc->wxperl_version;
    my $wxperl_number = $dc->wxperl_number;
    my $wxwin_version = $dc->wxwin_version;

    my $rpm_name = 'perl-Wx';
    my $bin_final_rpm = "$rpm_name-$wxperl_version-${rpm_release}_" .
      "wxgtk$wxwin_version.$rpm_arch.rpm";
    my $src_final_rpm = "$rpm_name-$wxperl_version-$rpm_release.src.rpm";
    my $bin_rpm = catfile( $buildarea, 'RPMS', $rpm_arch,
                           "$rpm_name-$wxperl_number-$rpm_release.$rpm_arch.rpm" );
    my $src_rpm = catfile( $buildarea, 'SRPMS',
                           "$rpm_name-$wxperl_number-$rpm_release.src.rpm" );

    @{$self}{qw(ccache buildarea bin_final_rpm src_final_rpm
                bin_rpm src_rpm)}
      = ( $ccache || '', $buildarea, $bin_final_rpm, $src_final_rpm,
          $bin_rpm, $src_rpm );
}

sub build_wxwidgets {
}

sub build_wxperl {
}

sub package_wxwidgets {
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    my $buildarea = $self->buildarea;

    my $contrib_makefiles = $dc->contrib_makefiles;
    my $rpm_spec = $dc->rpm_spec;
    my $wxgtk_directory = $dc->wxgtk_directory;
    my $remote_home = $dc->remote_home;
    my $wxgtk_archive = $dc->wxgtk_archive;
    my $wxwin_number = $dc->wxwin_number;
    my $distribution_dir = $dc->distribution_dir;

    $self->_exec_string( <<EOS );
#!/bin/sh

set -e
set -x

sudo rm -rf $buildarea
mkdir -p $buildarea
for d in RPMS RPMS/i386 SRPMS SOURCES BUILD SPECS; do
    mkdir -p $buildarea/\$d
done
EOS

    # copy files
    $self->_put_file( $dc->wxperl_src, catfile( $buildarea, 'SOURCES' ) );
    $self->_put_file( $dc->wxgtk_src, catfile( $buildarea, 'SOURCES' ) );
    $self->_put_file( $contrib_makefiles, catfile( $buildarea, 'SOURCES' ) );

    my $makefiles_tgz = basename $contrib_makefiles;
    my $got_contrib = 0;

    # generate spec file / basic sanity checks
    my $out_spec = "$buildarea/SPECS/" . basename( $rpm_spec );
    my( $rpm_release, $rpm_arch ) = qw(1 i386);

    my $tmpl = Text::Template->new( TYPE => 'FILE',
                                    SOURCE => $rpm_spec,
                                    DELIMITERS => [ '<%', '%>' ] );

    my $xxx = "`pwd`/../\$wxgtk_directory";
    my $makefile_flags =
        ( $got_contrib ? '' :
                         qq{ --extra-cflags="-I${xxx}/contrib/include" } .
                         qq{ --extra-libs="-L${xxx}/lib" } );

    my $spec;

    die "Error while filling template: $Text::Template::ERROR"
      unless $spec = $tmpl->fill_in( HASH =>
                                     { full_ver => $dc->wxperl_version,
                                       ver => $dc->wxperl_number,
                                       release => $rpm_release,
                                       wxgtk_version => $dc->wxwin_version,
                                       makefile_flags => $makefile_flags,
                                     } );

    $self->_put_string( $spec, $out_spec );

    # ccache support
    my $ccache = $self->ccache;
    my $functions = common_functions;

    # build
    $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=192.168.9.2:0.0
export wxgtk_directory=$wxgtk_directory
SRC=../SOURCES

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

if test "${got_contrib}" = "0"; then
    cd buildarea/BUILD
    extract_wx_archive \$SRC/${wxgtk_archive} "\$wxgtk_directory/contrib/*"
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

sudo rpmbuild -ba buildarea/SPECS/perl-Wx.spec

exit 0
EOT

    # rpm names
    my $bin_final_rpm = $self->bin_final_rpm;
    my $src_final_rpm = $self->src_final_rpm;
    my $bin_rpm = $self->bin_rpm;
    my $src_rpm = $self->src_rpm;

#    die "something went wrong while building"
#      unless -f $bin_rpm && -f $src_rpm;

    $self->_get_file( $src_rpm, "$distribution_dir/$src_final_rpm" );
    $self->_get_file( $bin_rpm, "$distribution_dir/$bin_final_rpm" );
}

sub install_wxperl {
    my $self = shift;
    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $irpm = catfile( $self->_distconfig->remote_home,
                        'buildarea', 'RPMS', $rpm_arch,
                        basename( $self->bin_rpm ) );

    $self->_exec_string( sprintf <<'EOT', $irpm );
#!/bin/sh

# set -e
set -x

rpms=`rpm -q -a | grep Wx`
if test "x$rpms" != "x"; then
  sudo rpm -e $rpms
fi

sudo rpm -i %s
EOT
}

sub build_submodules {
    my( $self,  @modules ) = @_;
    my $dc = $self->_distconfig;

    $self->_exec_string( "mkdir -p cpan2rpm" );
    $self->_put_file( $dc->data_dir . "/cpan2rpm/cpan2*",
                      $dc->remote_home . "/cpan2rpm" );

    foreach my $module ( @modules ) {
        next if $module =~ m/Wx-ActiveX/;

        my $package_src = $self->_distconfig->get_module_src( $module );
        my $src_base = basename( $package_src );
        my $package = $src_base; $package =~ s/\.tar\.gz|\.zip//;
        my $package_nover = $package; $package_nover =~ s/\-[^-]+$//;
        my $destination_dir = dirname( $package_src ) .
          '/' . $dc->wxperl_version;

        $self->_put_file( $package_src, $dc->remote_home );

        my $ccache = $self->ccache;

        # build
        $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
# \$functions

export DISPLAY=192.168.9.2:0.0

sudo perl cpan2rpm/cpan2rpm --name $package_nover $src_base
sudo rpmbuild -ba buildarea/SPECS/$package_nover.spec

exit 0
EOT

        my $bin_rpm = "buildarea/RPMS/*/perl-$package-1.i686.rpm";
        my $src_rpm = "buildarea/SRPMS/perl-$package-1.src.rpm";

#        die "something went wrong while building ($bin_rpm) ($src_rpm)"
#          unless defined( $bin_rpm ) && defined( $src_rpm ) &&
#            -f $bin_rpm && -f $src_rpm;

        my $src_final_rpm = basename( $src_rpm );
        my $bin_final_rpm = basename( $bin_rpm );
        my $wxwin_version = $dc->wxwin_version;
        my $wxperl_version = $dc->wxperl_version;
        $bin_final_rpm =~ s/(\.[^\.]+\.rpm)$/_wxperl${wxperl_version}_wxgtk${wxwin_version}${1}/;

        $self->_get_file( $src_rpm, "$destination_dir/$src_final_rpm" );
        $self->_get_file( $bin_rpm, "$destination_dir/$bin_final_rpm" );
    }
}

sub make_dist {
}

1;
