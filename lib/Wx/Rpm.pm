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
                           "$rpm_name-$wxperl_version-$rpm_release.$rpm_arch.rpm" );
    my $src_rpm = catfile( $buildarea, 'SRPMS',
                           "$rpm_name-$wxperl_version-$rpm_release.src.rpm" );

    @{$self}{qw(ccache buildarea bin_final_rpm src_final_rpm
                bin_rpm src_rpm)}
      = ( $ccache || '', $buildarea, $bin_final_rpm, $src_final_rpm,
          $bin_rpm, $src_rpm );
}

sub build_alien {
    my $self = shift;

    my $buildarea = $self->buildarea;

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
}

sub build_wxperl {
}

sub _package_x {
    my( $self, $rpm_spec, $src, $version, $number,
        $src_rpm, $bin_rpm, $src_final_rpm, $bin_final_rpm ) = @_;
    my $dc = $self->_distconfig;

    my $buildarea = $self->buildarea;

    my $remote_home = $dc->remote_home;
    my $wxwin_number = $dc->wxwin_number;
    my $distribution_dir = $dc->distribution_dir;

    # copy files
    $self->_put_file( $src, catfile( $buildarea, 'SOURCES' ) );

    # generate spec file / basic sanity checks
    my $base_spec = basename( $rpm_spec );
    my $out_spec = "$buildarea/SPECS/" . $base_spec;
    my( $rpm_release, $rpm_arch ) = qw(1 i386);

    my $tmpl = Text::Template->new( TYPE => 'FILE',
                                    SOURCE => $rpm_spec,
                                    DELIMITERS => [ '<%', '%>' ] );

    my $spec;

    die "Error while filling template: $Text::Template::ERROR"
      unless $spec = $tmpl->fill_in( HASH =>
                                     { full_ver => $version,
                                       ver => $number,
                                       release => $rpm_release,
                                       wxgtk_version => $dc->wxwin_version,
                                       makefile_flags => '',
                                     } );

    $self->_put_string( $spec, $out_spec );

    # ccache support
    my $ccache = $self->ccache;
    my $functions = common_functions;
    my $xhost = $dc->xhost;

    # build
    $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=$xhost
SRC=../SOURCES

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

sudo rpmbuild -ba buildarea/SPECS/$base_spec

exit 0
EOT

    $self->_get_file( $src_rpm, "$distribution_dir/$src_final_rpm" );
    $self->_get_file( $bin_rpm, "$distribution_dir/$bin_final_rpm" );
}

sub package_alien {
    my $self = shift;
    my $dc = $self->_distconfig;

    my $buildarea = $self->buildarea;
    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $alien_version = $dc->alien_version;
    my $alien_number = $dc->alien_number;
    my $wxwin_version = $dc->wxwin_version;

    my $rpm_name = 'perl-Alien-wxWidgets';
    my $bin_final_rpm = "$rpm_name-$alien_version-${rpm_release}_" .
      "wxgtk$wxwin_version.$rpm_arch.rpm";
    my $src_final_rpm = "$rpm_name-$alien_version-$rpm_release.src.rpm";
    my $bin_rpm = catfile( $buildarea, 'RPMS', $rpm_arch,
                           "$rpm_name-$alien_version-$rpm_release.$rpm_arch.rpm" );
    my $src_rpm = catfile( $buildarea, 'SRPMS',
                           "$rpm_name-$alien_version-$rpm_release.src.rpm" );

    _package_x( $self, 'perl-Alien-wxWidgets.spec', $dc->alien_src,
                $dc->alien_version,
                $dc->alien_number, $src_rpm, $bin_rpm,
                $src_final_rpm, $bin_final_rpm );

    _install_x( $self, $bin_rpm, '"Alien\\|Wx"' );
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    _package_x( $self, $dc->rpm_spec, $dc->wxperl_src, $dc->wxperl_version,
                $dc->wxperl_number, $self->src_rpm, $self->bin_rpm,
                $self->src_final_rpm, $self->bin_final_rpm );

    return;

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

    # generate spec file / basic sanity checks
    my $out_spec = "$buildarea/SPECS/" . basename( $rpm_spec );
    my( $rpm_release, $rpm_arch ) = qw(1 i386);

    my $tmpl = Text::Template->new( TYPE => 'FILE',
                                    SOURCE => $rpm_spec,
                                    DELIMITERS => [ '<%', '%>' ] );

    my $xxx = "`pwd`/../\$wxgtk_directory";
    my $spec;

    die "Error while filling template: $Text::Template::ERROR"
      unless $spec = $tmpl->fill_in( HASH =>
                                     { full_ver => $dc->wxperl_version,
                                       ver => $dc->wxperl_number,
                                       release => $rpm_release,
                                       wxgtk_version => $dc->wxwin_version,
                                       makefile_flags => '',
                                     } );

    $self->_put_string( $spec, $out_spec );

    # ccache support
    my $ccache = $self->ccache;
    my $functions = common_functions;
    my $xhost = $dc->xhost;

    # build
    $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=$xhost
export wxgtk_directory=$wxgtk_directory
SRC=../SOURCES

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
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

sub _install_x {
    my( $self, $bin_rpm, $delete ) = @_;
    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $irpm = catfile( $self->_distconfig->remote_home,
                        'buildarea', 'RPMS', $rpm_arch,
                        basename( $bin_rpm ) );

    $self->_exec_string( sprintf <<'EOT', $delete, $irpm );
#!/bin/sh

# set -e
set -x

rpms=`rpm -q -a | grep %s`
if test "x$rpms" != "x"; then
  sudo rpm -e $rpms
fi

sudo rpm -i %s
EOT
}

sub install_wxperl {
    my $self = shift;

    _install_x( $self, $self->bin_rpm, 'Wx' );

    return;

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

    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $buildarea = $self->buildarea;

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
	my $xhost = $dc->xhost;

        # build
        $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
# \$functions

export DISPLAY=$xhost

sudo perl cpan2rpm/cpan2rpm --buildarch i386 --name $package_nover $src_base
sudo rpmbuild -ba buildarea/SPECS/$package_nover.spec

exit 0
EOT

        my $bin_rpm = "$buildarea/RPMS/${rpm_arch}/perl-$package-${rpm_release}.i386.rpm";
        my $src_rpm = "$buildarea/SRPMS/perl-$package-${rpm_release}.src.rpm";

#        die "something went wrong while building ($bin_rpm) ($src_rpm)"
#          unless defined( $bin_rpm ) && defined( $src_rpm ) &&
#            -f $bin_rpm && -f $src_rpm;

        my $src_final_rpm = basename( $src_rpm );
        my $bin_final_rpm = basename( $bin_rpm );
        my $wxwin_version = $dc->wxwin_version;
        my $wxperl_version = $dc->wxperl_version;
        $bin_final_rpm =~ s/(\.[^\.]+\.rpm)$/_wxperl${wxperl_version}_wxgtk${wxwin_version}${1}/;

        print "$src_rpm => $destination_dir/$src_final_rpm\n";
        $self->_get_file( $src_rpm, "$destination_dir/$src_final_rpm" );
        print "$bin_rpm $destination_dir/$bin_final_rpm\n";
        $self->_get_file( $bin_rpm, "$destination_dir/$bin_final_rpm" );
    }
}

sub make_dist {
}

1;
