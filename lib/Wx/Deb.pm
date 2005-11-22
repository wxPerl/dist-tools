package Wx::Deb;

use strict;
use warnings;
use base 'Wx::Base';
use DistUtils;
use DistScripts;
use DistConfig ();
use File::Basename qw(basename dirname);
use Text::Template;

sub catfile { File::Spec::Unix->catfile( @_ ) }
sub catdir { File::Spec::Unix->catdir( @_ ) }

sub set_options {
    my( $self, %args ) = @_;

    my $dc = DistConfig->new( $args{config}, 'Debian' );

    $self->{distconfig} = $dc;

    my $remote_home = $dc->remote_home;
    my $data_dir = $dc->data_dir;

    my( $deb_release, $deb_arch ) = ( undef, 'i386' );

    open my $in, "< $data_dir/debian/changelog" or die "open";
    my $rel = '';
    while( <$in> ) {
        m/^\s*\S+\s+\(([^\)]+)\)/ and $rel = $1 and last;
    }
    close $in;
    die "Unable to parse changelog" unless length $rel;
    $rel =~ m/-(\d+)/; $deb_release = $1;
    die "Unable to parse changelog" unless length $deb_release;

    my $ccache = eval( $dc->ccache ? ccache_vars : '' );
    my $buildarea = catdir( $dc->remote_home, 'buildarea' );
    my $wxperl_version = $dc->wxperl_version;
    my $wxperl_number = $dc->wxperl_number;
    my $wxwin_version = $dc->wxwin_version;

    my $wxgtk_deb_ver = $wxwin_version; $wxgtk_deb_ver =~ s/\.\d+[^.]*$//;
    my $bin_deb = "libwx-perl-wxgtk${wxgtk_deb_ver}_${wxperl_number}-" .
      "${deb_release}_${deb_arch}.deb";
    my $bin_deb_final = "libwx-perl-wxgtk${wxgtk_deb_ver}_${wxperl_version}-" .
      "${deb_release}_${deb_arch}.deb";
    my $src_dir = "libwx-perl-${wxperl_number}";
    my $src_base = "libwx-perl_${wxperl_number}";
    my $src_diff = "$src_base-${deb_release}.diff.gz";
    my $src_dsc = "$src_base-${deb_release}.dsc";
    my $src_tgz = "$src_base.orig.tar.gz";
    my $src_tgz_all = "$src_base-${deb_release}.deb.src.tar.gz";

    @{$self}{qw(ccache buildarea bin_deb bin_deb_final src_dir
                src_base src_diff src_dsc src_tgz src_tgz_all
                deb_release deb_arch)}
      = ( $ccache || '', $buildarea, $bin_deb, $bin_deb_final, $src_dir,
          $src_base, $src_diff, $src_dsc, $src_tgz, $src_tgz_all,
          $deb_release, $deb_arch );
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

    my $remote_home = $dc->remote_home;
    my $wxperl_version = $dc->wxperl_version;
    my $wxwin_number = $dc->wxwin_number;
    my $wxperl_number = $dc->wxperl_number;
    my $distribution_dir = $dc->distribution_dir;
    my $src_dir = $self->src_dir;
    my $src_diff = $self->src_diff;
    my $src_dsc = $self->src_dsc;
    my $src_tgz = $self->src_tgz;
    my $src_tgz_all = $self->src_tgz_all;

    $self->_exec_string( <<EOS );
#!/bin/sh

set -e
set -x

rm -rf $buildarea
mkdir -p $buildarea/debian
EOS

    # copy files
    $self->_put_file( $dc->wxperl_src, $buildarea );

    foreach my $f ( qw(changelog control copyright postinst prerm rules) ) {
        $self->_put_file( catfile( $dc->data_dir, 'debian', $f ),
                          catfile( $buildarea, 'debian' ) );
    }

    # ccache support
    my $ccache = $self->ccache;
    my $xhost = $dc->xhost;
    my $functions = common_functions;

    # build
    $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=$xhost

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

cd buildarea

zcat Wx-${wxperl_version}.tar.gz | tar -x -f -
mv Wx-${wxperl_number} $src_dir
mv Wx-${wxperl_version}.tar.gz $src_tgz
chmod +x debian/rules
mv debian $src_dir

# now build it!
dpkg-source -b $src_dir $src_tgz
cd $src_dir
fakeroot debian/rules binary-arch

cd ..
tar -c -z -f $src_tgz_all $src_diff $src_dsc $src_tgz

exit 0
EOT

    # deb names
    my $bin_final_deb = $self->bin_deb_final;
    my $bin_deb = $self->bin_deb;

    $self->_get_file( catfile( $self->buildarea, $src_tgz_all ),
                      "$distribution_dir/$src_tgz_all" );
    $self->_get_file( catfile( $self->buildarea, $bin_deb ),
                      "$distribution_dir/$bin_final_deb" );
}

sub install_wxperl {
    return;

    my $self = shift;
    my $irpm = catfile( $self->_distconfig->remote_home,
                        'buildarea', basename( $self->bin_rpm ) );

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
    return;

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
	my $xhost = $dc->xhost;

        # build
        $self->_exec_string( <<EOT );
#!/bin/sh

set -e
set -x

$ccache
# \$functions

export DISPLAY=$xhost

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
