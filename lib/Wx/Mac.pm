package Wx::Mac;

use strict;
use warnings;
use base 'Wx::Base';
use FindBin;
use DistUtils qw(extract my_chdir check_file my_system);
use File::Spec::Functions qw(catdir updir);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath rmtree);
use DistConfig ();
use Config;

my $buildpkg = "$FindBin::RealBin/mac/buildpkg.py";
my $builddmg = "$FindBin::RealBin/mac/makedmg";
my $prefix = "/usr/local";

$ENV{MACOSX_DEPLOYMENT_TARGET} = '10.3';

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
                    devel devel/perl devel/wxWidgets devel/wxPerl
                    build build/perl build/wxPerl build/wxWidgets build/dmg);

    @{$self}{qw(wxwin_configure_flags wxperl_configure_flags
                wxwin_src_dir wxperl_src_dir)} =
      ( "--prefix=$prefix --with-opengl --disable-compat24" .
          ( $dc->wxperl_unicode ? " --enable-unicode" :
                                  " --disable-unicode" ) .
          " --disable-compat22",
        "",
        "$tmpdir/devel/wxWidgets",
        "$tmpdir/devel/wxPerl",
      );
}

sub build_wxwidgets {
    my $self = shift;
    my $dc = $self->_distconfig;

    my $wxmac_directory = $dc->wxmac_directory;
    my $wxwindows_src_dir = $self->wxwin_src_dir;
    my $tmpdir = $self->_distconfig->temp_dir;

    my_chdir $wxwindows_src_dir;
    extract $dc->wxmac_src;
    foreach my $arch ( @{$dc->wxmac_archives} ) {
        extract $arch;
    }
    my_system "chmod +x $wxwindows_src_dir/$wxmac_directory/distrib/mac/shared-ld-sh" if -f "$wxwindows_src_dir/$wxmac_directory/distrib/mac/shared-ld-sh";
    my_chdir "$tmpdir/build/wxWidgets";
    my_system "sh $wxwindows_src_dir/$wxmac_directory/configure " .
      $self->wxwin_configure_flags;
    my_system "make all";
    my_chdir 'contrib/src/stc';
    my_system 'make all';
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

    local $ENV{WX_CONFIG} = "$tmpdir/build/wxWidgets/wx-config --prefix=$wxwindows_src_dir --exec-prefix=$tmpdir/build/wxWidgets";

    my_chdir "$tmpdir/build/wxPerl";

    my_system "perl $wxperl_src_dir/$wxperl_directory/Makefile.PL --mksymlinks"
      . $self->wxperl_configure_flags;
    my_system "make all";
}

sub package_wxwidgets {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    my_chdir "$tmpdir/build/wxWidgets";
    my_system "rm -rf $tmpdir/install/wxWidgets/*";
    my_system "make prefix=$tmpdir/install/wxWidgets$prefix install";
    my_chdir 'contrib/src/stc';
    my_system "make prefix=$tmpdir/install/wxWidgets$prefix install";

    my $rsrc_dir = "$tmpdir/build/rsrc";

    my $unicode = $dc->wxperl_unicode ? 'unicode' : 'ansi';
    my $release = 'release';
    my $number = $dc->wxwin_number; $number =~ s/\.\d+$//g;

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

    build_pkg( $dc->temp_dir . '/build', "wxWidgets", $dc->wxwin_version,
               "wxWidgets " . $dc->wxwin_version . " installer",
               "$tmpdir/install/wxWidgets",
               $rsrc_dir,
               "$tmpdir/build/dmg" );
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $tmpdir = $dc->temp_dir;

    my_chdir "$tmpdir/build/wxPerl";
    my_system "rm -rf $tmpdir/install/wxPerl/*";
    my_system "make DESTDIR=$tmpdir/install/wxPerl install";

    my $rsrc_dir = "$tmpdir/build/rsrc";
    my $wxperl_version = $dc->wxperl_version;

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

    build_pkg( $dc->temp_dir . '/build', "wxPerl", $wxperl_version,
               "wxPerl $wxperl_version installer", "$tmpdir/install/wxPerl",
               $rsrc_dir,
               "$tmpdir/build/dmg" );

    my_chdir "$tmpdir/build/dmg";
    my_system "ditto -c -k --rsrc $tmpdir/install/wxPerl/usr/bin/wxPerl " .
              "wxPerl.pkg/Contents/Resources/wxPerl.zip";
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
    my $dmg = "wxPerl-" . $dc->wxperl_version .
              ( $dc->wxperl_unicode ? '-u' : '' );
    my $data_dir = $dc->data_dir;

    my_system "cp $data_dir/data/OSX-Readme.rtf $tmpdir/build/dmg/Read-me.rtf";

    build_dmg( $dmg, "$tmpdir/build/dmg", "$tmpdir/build" );

    my_system "cp $tmpdir/build/$dmg.dmg " . $dc->distribution_dir;
}

1;
