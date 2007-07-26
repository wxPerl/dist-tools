package Wx::Mac;

use strict;
use warnings;
use base 'Wx::Base';
use FindBin;
use DistUtils qw(extract my_chdir check_file my_system my_copy);
use File::Spec::Functions qw(catdir updir);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath rmtree);
use DistConfig ();
use Config;

my $buildpkg = "$FindBin::RealBin/mac/buildpkg.py";
my $builddmg = "$FindBin::RealBin/mac/makedmg";
my $prefix = "/usr/local";
my $osx_version = `uname -r` =~ m/^8\./ ? '10.4' : '10.3';

$ENV{MACOSX_DEPLOYMENT_TARGET} = $osx_version;

sub build_pkg {
    my( $base, $name, $version, $desc, $directory, $rsrc_dir, $destdir ) = @_;

    my_chdir "$base";
    rmtree "$destdir/$name.pkg";
    die unless -d $directory;
    my_system 'python', $buildpkg, qq{--Title=$name},
                                   qq{--Version=$version},
                                   qq{--Description=$desc},
                                   qq{--NeedsAuthorization=YES},
                                   qq{--Relocatable=NO},
                                   qq{--InstallOnly=YES},
                                   $directory,
                                   ( defined $rsrc_dir ? $rsrc_dir : () );
    my_system "mv $name.pkg $destdir";
}

sub build_dmg {
    my( $name, $srcdir, $destdir ) = @_;

    my_system "rm -f $destdir/$name.dmg";
    my_system 'perl', $builddmg, $srcdir, $destdir, $name;
}

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub set_options {
    my( $self, %args ) = @_;

    my $dc = DistConfig->new( $args{config}, '' );

    $self->{distconfig} = $dc;

    my $tmpdir = $dc->temp_dir;

    rmtree $tmpdir;
    mkpath $tmpdir;
    my_chdir $tmpdir;
    mkdir $_ for qw(install install/perl install/wxWidgets install/wxPerl
                    install/Alien-wxWidgets
                    devel devel/perl devel/wxWidgets devel/wxPerl
                    build build/perl build/wxPerl build/wxWidgets build/dmg
                    build/dmg/Alien build/dmg/wxPerl);

    @{$self}{qw(wxwin_configure_flags wxperl_configure_flags
                wxwin_src_dir wxperl_src_dir alien_build)} =
      ( "--prefix=$prefix --with-opengl --disable-compat24" .
          ( $dc->wxperl_unicode ? " --enable-unicode" :
                                  " --disable-unicode" ) .
          " --disable-compat22 --with-libtiff=builtin --with-libjpeg=builtin" .
	  " --with-expat=builtin --with-libpng=builtin" .
          " --enable-universal_binary --enable-monolithic",
        "",
        "$tmpdir/devel/wxWidgets",
        "$tmpdir/devel/wxPerl",
        "$tmpdir/build/Alien-wxWidgets-" . $dc->alien_version,
      );
}

sub _new_env {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    my $alien_blib = $self->alien_build;
    my $alien_inst = "$tmpdir/install/Alien-wxWidgets";
    my $alien_base = $Config{sitearch} . "/Alien/wxWidgets";
    my $ver = $dc->wxwin_version; $ver =~ tr/\./_/;

    return ( %ENV,
             PERL5OPT          => "-Mblib=$alien_blib/blib",
             ALIEN_WX_PREFIXES => "$alien_base,$alien_inst$alien_base",
             DYLD_LIBRARY_PATH => "$alien_inst$alien_base/mac_${ver}_uni/lib",
             );
}

sub build_alien {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    # prepare wxWidgets sources
    my_chdir "$tmpdir/build";

#    my $uc = $dc->wxperl_unicode ? '-u' : '';
#    my $archive = "a-wxMac-" . $dc->wxwin_version . $uc . '.tar.gz';
    rmtree $self->alien_build;
#    if( -f $archive ) {
#        extract $archive;
#    } else {
        extract( $dc->alien_src );
        my_copy( $dc->wxmac_src, $self->alien_build );

        my $uc = $dc->wxperl_unicode ? ' --unicode --mslu' :
                                       ' --no-unicode --no-mslu';

        my_chdir catdir( $self->alien_build );
        my_system "perl Build.PL$uc --build_wx --build_wx_opengl --monolithic --universal --source=tar.bz2";
        my_system 'perl Build';
        my_system "perl Build destdir=$tmpdir/install/Alien-wxWidgets install";

#        my_chdir $dc->temp_dir;
#        my_system "tar cf - Alien-wxWidgets-0.04 | gzip -9 > $archive";
#    }
}

sub build_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    my $wxperl_directory = $dc->wxperl_directory;
    my $wxwindows_src_dir = $self->wxwin_src_dir;
    my $wxperl_src_dir = $self->wxperl_src_dir;
    my $tmpdir = $self->_distconfig->temp_dir;

    my_chdir $wxperl_src_dir;
    extract $dc->wxperl_src;

    local %ENV = $self->_new_env;
    # warn $_, ' => ', $ENV{$_}, "\n" foreach keys %ENV;
    my $uc = $dc->wxperl_unicode ? ' --wx-unicode' :
                                   ' --no-wx-unicode';

    my_chdir "$tmpdir/build/wxPerl";

    my_system "perl $wxperl_src_dir/$wxperl_directory/Makefile.PL --mksymlinks $uc --no-wx-debug"
      . $self->wxperl_configure_flags;
    my_system "make all test";
}

sub package_alien {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    my_chdir $self->alien_build;
#    my_system "rm -rf $tmpdir/install/wxWidgets/*";
#    my_system "make prefix=$tmpdir/install/wxWidgets$prefix install";
#    my_chdir 'contrib/src/stc';
#    my_system "make prefix=$tmpdir/install/wxWidgets$prefix install";

    my $rsrc_dir = "$tmpdir/build/rsrc";

    my $unicode = $dc->wxperl_unicode ? 'unicode' : 'ansi';
    my $release = 'release';
    my $number = $dc->wxwin_number; $number =~ s/\.\d+$//g;

=pod

    mkdir $rsrc_dir;
    local *OUT;
    open OUT, "> $rsrc_dir/postflight";
    printf OUT <<'EOT', $unicode, $release, $number;
#!/bin/sh -e

PATH=/usr/local/bin:$PATH; export PATH

for wxconfig in /usr/local/bin/wx-config; do
    if test -L $wxconfig; then
        rm $wxconfig
    fi

    ln -s /usr/local/lib/wx/config/mac-%s-%s-%s $wxconfig
done

exit 0
EOT
    close OUT;
    my_system "chmod +x $rsrc_dir/postflight";

=cut

    build_pkg( $dc->temp_dir . '/build', "Alien-wxWidgets", $dc->alien_version,
               "Alien::wxWidgets " . $dc->alien_version . " installer",
               "$tmpdir/install/Alien-wxWidgets",
               undef,
               "$tmpdir/build/dmg/Alien" );
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    local %ENV = $self->_new_env;

    my_chdir "$tmpdir/build/wxPerl";
    my_system "rm -rf $tmpdir/install/wxPerl/*";
    my_system "make DESTDIR=$tmpdir/install/wxPerl install";

    my $rsrc_dir = "$tmpdir/build/rsrc";
    my $wxperl_version = $dc->wxperl_version;

=pod

    mkdir $rsrc_dir;
    local *OUT;
    open OUT, "> $rsrc_dir/postflight";
    print OUT <<'EOT';
#!/bin/sh -e

PATH=/usr/local/bin:$PATH; export PATH
WXPERL=`dirname $0`/wxPerl.zip

cd /usr/bin
ditto -x -k --rsrc $WXPERL .

exit 0
EOT
    close OUT;
    my_system "chmod +x $rsrc_dir/postflight";

=cut

    build_pkg( $dc->temp_dir . '/build', "wxPerl", $wxperl_version,
               "wxPerl $wxperl_version installer", "$tmpdir/install/wxPerl",
               undef,
               "$tmpdir/build/dmg/wxPerl" );

    my_chdir "$tmpdir/build/dmg";
#    my_system "ditto -c -k --rsrc $tmpdir/install/wxPerl/usr/bin/wxPerl " .
#              "wxPerl.pkg/Contents/Resources/wxPerl.zip";
}

sub install_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

}

sub build_submodules {
    my( $self,  @modules ) = @_;

}

sub make_dist {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;
    my $alien_dmg = "Alien-wxWidgets-" . $dc->alien_version . '-wxmac' .
                     $dc->wxwin_version . '-osx' . $osx_version .
                       ( $dc->wxperl_unicode ? '-u' : '' );
    my $wxperl_dmg = "wxPerl-" . $dc->wxperl_version . '-wxmac' .
                     $dc->wxwin_version . '-osx' . $osx_version .
                       ( $dc->wxperl_unicode ? '-u' : '' );
    my $data_dir = $dc->data_dir;

    my_system "cp $data_dir/data/OSX-Readme.rtf $tmpdir/build/dmg/Alien/Read-me.rtf";
    my_system "cp $data_dir/data/OSX-Readme.rtf $tmpdir/build/dmg/wxPerl/Read-me.rtf";

    build_dmg( $alien_dmg, "$tmpdir/build/dmg/Alien", "$tmpdir/build" );
    build_dmg( $wxperl_dmg, "$tmpdir/build/dmg/wxPerl", "$tmpdir/build" );

    my_system "cp $tmpdir/build/$alien_dmg.dmg " . $dc->distribution_dir;
    my_system "cp $tmpdir/build/$wxperl_dmg.dmg " . $dc->distribution_dir;
}

1;
