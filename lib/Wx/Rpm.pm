package Wx::Rpm;

use strict;
use warnings;
use DistUtils;
use DistScripts;
use DistConfig ();
use File::Spec::Functions qw(catfile catdir updir);
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename dirname);
use Text::Template;

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub set_options {
    my( $self, %args ) = @_;

    my $dc = DistConfig->new( $args{config} );

    $self->{distconfig} = $dc;

    my $chroot_home = $dc->chroot_home;
    my $rh_chroot_dir = $dc->rh_chroot_dir;

    check_dir( $dc->rh_chroot_dir );
    check_dir( catdir( $dc->rh_chroot_dir, $dc->chroot_home ) );

    open OUT, "> " . catfile( $dc->rh_chroot_dir, $dc->chroot_home,
                              '.rpmmacros' )
      or die "open";
    print OUT "\%_topdir $chroot_home/buildarea\n";
    close OUT;

    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $rh_ccache = $dc->rh_ccache;
    my $ccache = eval( $rh_ccache ? ccache_vars : '' );
    my $buildarea = catdir( $dc->rh_chroot_dir, $dc->chroot_home, 'buildarea' );    my $wxperl_version = $dc->wxperl_version;
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
      = ( $ccache, $buildarea, $bin_final_rpm, $src_final_rpm,
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

    rmtree( $buildarea ) if -d $buildarea;
    mkpath( $buildarea ) or die "mkpath '$buildarea'"
      unless -d $buildarea;
    foreach my $i ( qw(RPMS RPMS/i386 SRPMS SOURCES BUILD SPECS) ) {
        my $dir = catdir( $buildarea, $i );
        mkdir( $dir, 0755 ) or die "mkdir '$dir'"
          unless -d $dir;
    }

    my $wxperl_src = $dc->wxperl_src;
    my $wxgtk_src = $dc->wxgtk_src;
    my $contrib_makefiles = $dc->contrib_makefiles;
    my $rh_rpm_spec = $dc->rh_rpm_spec;
    my $wxgtk_directory = $dc->wxgtk_directory;
    my $wxperl_static = $dc->wxperl_static;
    my $wxperl_version = $dc->wxperl_version;
    my $wxperl_number = $dc->wxperl_number;
    my $wxwin_version = $dc->wxwin_version;
    my $rh_chroot_dir = $dc->rh_chroot_dir;
    my $chroot_home = $dc->chroot_home;
    my $wxgtk_archive = $dc->wxgtk_archive;
    my $wxwin_number = $dc->wxwin_number;
    my $distribution_dir = $dc->distribution_dir;

    # copy files
    my_system "cp $wxperl_src " . catdir( $buildarea, 'SOURCES' );
    my_system "cp $wxgtk_src " . catdir( $buildarea, 'SOURCES' )
      if length $wxgtk_src;
    my_system "cp $contrib_makefiles " . catdir( $buildarea, 'SOURCES' );

    my $makefiles_tgz = basename $contrib_makefiles;
    my $got_contrib = 0;

    # generate spec file / basic sanity checks
    my $out_spec = catdir( $buildarea, 'SPECS' ) . "/" .
      basename( $rh_rpm_spec );
    my( $rpm_release, $rpm_arch ) = qw(1 i386);

    my $tmpl = Text::Template->new( TYPE => 'FILE',
                                    SOURCE => $rh_rpm_spec,
                                    DELIMITERS => [ '<%', '%>' ] );

    print "Writing '$out_spec'\n";
    open OUT, "> $out_spec" or die "unable to open '$out_spec' for output";

    my $xxx = "`pwd`/../\$wxgtk_directory";
    my $makefile_flags =        #'"'.
      ( $wxperl_static ? '--static ' : '' )
        . ( $got_contrib ? '' : qq{--extra-cflags="-I${xxx}/contrib/include" --extra-libs="-L${xxx}/lib" } )
          . qq("");
    ;

    die "Error while filling template: $Text::Template::ERROR"
      unless $tmpl->fill_in( OUTPUT => \*OUT,
                             HASH => { full_ver => $wxperl_version,
                                       ver => $wxperl_number,
                                       release => $rpm_release,
                                       wxgtk_version => $wxwin_version,
                                       makefile_flags => $makefile_flags,
                                     } );
    close OUT;

    # ccache support
    my $ccache = $self->ccache;
    my $functions = common_functions;

    open OUT, "> " .catfile( $rh_chroot_dir, $chroot_home, 'buildrpm' )
      or die "open";
    print OUT <<EOT;
#!/bin/sh

set -e
set -x

$ccache
$functions

export DISPLAY=192.168.9.2:0.0
dname=wxWin
export wxgtk_directory=$wxgtk_directory
SRC=../SOURCES

if test "${wxperl_static}" = "1"; then
    cd buildarea/BUILD
    extract_wx_archive \$SRC/${wxgtk_archive}

    for i in inst inst/\$dname; do
      test -d \$i || mkdir \$i
    done
    cd \$wxgtk_directory
    # now in buildarea/BUILD/wxGTK-xxx
    test -d build || mkdir build
    cd build
    # now in buildarea/BUILD/wxGTK-xxx/build
    sh ../configure --with-gtk --disable-shared --prefix=`pwd`/../../inst/\$dname
    make all install
    cd contrib/src
    # now in buildarea/BUILD/wxGTK-xxx/build/contrib/src
    for i in xrc stc; do
      test -d \$i && cd \$i && make all install && cd ..
    done
    cd ../..
    # now in buildarea/BUILD/wxGTK-xxx/build
    cd ../..
    # now in buildarea/BUILD
    export PATH=`pwd`/inst/\$dname/bin:\$PATH
    # back were we started
    cd ../..
elif test "${got_contrib}" = "0"; then
    cd buildarea/BUILD
    if test "\$wxgtk_directory" = ""; then
        extract_wx_archive \$SRC/${wxgtk_archive} "contrib/*"
    else
        extract_wx_archive \$SRC/${wxgtk_archive} "\$wxgtk_directory/contrib/*"
    fi
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

if test "$wxwin_number" != "`wx-config --version`"; then
  echo "found version '`wx-config --version`', wanting '$wxwin_number'"
  exit 1
fi

rpmbuild -ba buildarea/SPECS/perl-Wx.spec

exit 0
EOT
    close OUT;

    # build
    my $ch_arg = basename( $rh_chroot_dir );
    my_system "sudo do_chroot $ch_arg '/bin/sh' '$chroot_home/buildrpm'";

    # rpm names
    my $bin_final_rpm = $self->bin_final_rpm;
    my $src_final_rpm = $self->src_final_rpm;
    my $bin_rpm = $self->bin_rpm;
    my $src_rpm = $self->src_rpm;

    die "something went wrong while building"
      unless -f $bin_rpm && -f $src_rpm;

    my_system "cp $src_rpm $distribution_dir/$src_final_rpm";
    my_system "cp $bin_rpm $distribution_dir/$bin_final_rpm";
}

sub install_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $bin_final_rpm = $self->bin_final_rpm;
    my $distribution_dir = $dc->distribution_dir;
    my $ch_arg = basename( $dc->rh_chroot_dir );
    my $chroot_home = $dc->chroot_home;
    my( $rpm_release, $rpm_arch ) = qw(1 i386);
    my $irpm = catfile( $dc->chroot_home, 'buildarea', 'RPMS', $rpm_arch,
                        basename( $self->bin_rpm ) );
    my $iscript = catfile( $dc->rh_chroot_dir, $dc->chroot_home, 'instrpm' );

    open OUT, "> " . $iscript
      or die "open";
    print OUT <<EOT;
#!/bin/sh

# set -e
set -x

rpms=`rpm -q -a | grep Wx`
if test "x\$rpms" != "x"; then
  rpm -e \$rpms
fi

cd
rpm -i $irpm

EOT
    close OUT;

    my_system "chmod 755 $iscript";
    my_system "sudo do_chroot $ch_arg '/bin/su' -c '$chroot_home/instrpm'";
}

sub build_submodules {
    my( $self,  @modules ) = @_;
    my $dc = $self->_distconfig;

    foreach my $module ( @modules ) {
        next if $module =~ m/Wx-ActiveX/;

        my $package_src = $self->_distconfig->get_module_src( $module );
        my $src_base = basename( $package_src );
        my $package = $src_base; $package =~ s/\.tar\.gz|\.zip//;
        my $package_nover = $package; $package_nover =~ s/\-[^-]+$//;
        my $chroot_home = $dc->chroot_home;
        my $home = catdir( $dc->rh_chroot_dir, $dc->chroot_home );
        my $buildarea = $self->buildarea;
        my $destination_dir = dirname( $package_src ) .
          '/' . $dc->wxperl_version;
        my $data_dir = $dc->data_dir;

        my_chdir $home;
        my_system "cp $package_src $home";
        my_system "cp -R $data_dir/cpan2rpm $home";

        my $ccache = $self->ccache;

        open OUT, "> " .catfile( $dc->rh_chroot_dir,
                                 $dc->chroot_home, 'buildrpm' )
          or die "open";
        print OUT <<EOT;
#!/bin/sh

set -e
set -x

$ccache
# \$functions

export DISPLAY=192.168.9.2:0.0

perl cpan2rpm/cpan2rpm --name $package_nover $src_base
#rpmbuild -ba buildarea/SPECS/perl-$package_nover.spec

exit 0
EOT
        close OUT;

        # build
        my $ch_arg = basename( $dc->rh_chroot_dir );
        my_system "sudo do_chroot $ch_arg '/bin/sh' '$chroot_home/buildrpm'";

        my $bin_rpm =
          ( glob( catfile( $buildarea, 'RPMS', '*', "*$package_nover*.rpm" ) ) )[0];
        my $src_rpm =
          ( glob( catfile( $buildarea, 'SRPMS', "*$package_nover*.rpm" ) ) )[0];

        die "something went wrong while building ($bin_rpm) ($src_rpm)"
          unless defined( $bin_rpm ) && defined( $src_rpm ) &&
            -f $bin_rpm && -f $src_rpm;

        my $src_final_rpm = basename( $src_rpm );
        my $bin_final_rpm = basename( $bin_rpm );
        my $wxwin_version = $dc->wxwin_version;
        my $wxperl_version = $dc->wxperl_version;
        $bin_final_rpm =~ s/(\.[^\.]+\.rpm)$/_wxperl${wxperl_version}_wxgtk${wxwin_version}${1}/;

        my_system "cp $src_rpm $destination_dir/$src_final_rpm";
        my_system "cp $bin_rpm $destination_dir/$bin_final_rpm";
    }
}

sub make_dist {
}

sub _distconfig { $_[0]->{distconfig} }

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
