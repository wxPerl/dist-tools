#!/usr/bin/perl -w

use strict;

use FindBin;
use lib "$FindBin::RealBin/lib";
use DistConfig;
use DistUtils qw(my_chdir my_system my_unlink extract);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catfile catdir);

my $buildpkg = "$FindBin::RealBin/mac/buildpkg.py";
my $builddmg = "$FindBin::RealBin/mac/makedmg";

my $tmpdir = "/Users/mbarbon/buildtmp";
my $prefix = '/usr/local';

my $perl5_configure_flags = "-des -Dusethreads -Duseshrplib -Dprefix=$prefix";
my $wxwindows_configure_flags = "--prefix=$prefix --with-opengl --disable-compat24 --disable-compat22";
my $wxperl_configure_flags; # = "--disable-xrc --disable-stc";

my $perl_version = '5.8.3';
my $perl5_src = "/Users/mbarbon/share/humptydumpty/scratch/perl-5.8.3.tar.bz2";

my $build_perl = 0;
my $build_wxwindows = 1;
my $build_wxperl = 1;

rmtree $tmpdir;
mkpath $tmpdir;
my_chdir $tmpdir;
mkdir $_ for qw(install install/perl install/wxWindows install/wxPerl
                devel devel/perl devel/wxWindows devel/wxPerl
                build build/perl build/wxPerl build/wxWindows build/dmg);

my $perl5_src_dir = "$tmpdir/devel/perl";
my $wxwindows_src_dir = "$tmpdir/devel/wxWindows";
my $wxperl_src_dir = "$tmpdir/devel/wxPerl";

if( $build_perl ) {
    my_chdir $perl5_src_dir;
    extract $perl5_src;
    my_chdir "$tmpdir/build/perl";
    my_unlink 'Policy.sh' if -f 'Policy.sh';
    my_unlink 'config.sh' if -f 'config.sh';
    my_system "sh $perl5_src_dir/perl-${perl_version}/Configure -Dmksymlinks $perl5_configure_flags";
    my_system "make all";
}

if( $build_wxwindows ) {
    my_chdir $wxwindows_src_dir;
    extract $wxmac_src;
    my_system "chmod +x $wxwindows_src_dir/$wxmac_directory/distrib/mac/shared-ld-sh" if -f "$wxwindows_src_dir/$wxmac_directory/distrib/mac/shared-ld-sh";
    my_chdir "$tmpdir/build/wxWindows";
    my_system "sh $wxwindows_src_dir/$wxmac_directory/configure $wxwindows_configure_flags";
    my_system "make all";
    my_chdir 'contrib/src/xrc';
    my_system 'make all';
    my_chdir '../stc';
    my_system 'make all';
}

if( $build_wxperl ) {
    my_chdir $wxperl_src_dir;
    extract $wxperl_src;

    local $ENV{WX_CONFIG} = "$tmpdir/build/wxWindows/wx-config --prefix=$wxwindows_src_dir --exec-prefix=$tmpdir/build/wxWindows" if $build_wxwindows;

    my_chdir "$tmpdir/build/wxPerl";

    my_system "perl $wxperl_src_dir/$wxperl_directory/Makefile.PL --mksymlinks $wxperl_configure_flags";
    my_system "make all";
#    my_system "make test";
}

# install
if( $build_perl ) {
    my_chdir "$tmpdir/build/perl";
    my_system "rm -rf $tmpdir/install/perl/*";
    my_system "make DESTDIR=$tmpdir/install/perl install";
}

if( $build_wxwindows ) {
    my_chdir "$tmpdir/build/wxWindows";
    my_system "rm -rf $tmpdir/install/wxWindows/*";
    my_system "make prefix=$tmpdir/install/wxWindows$prefix install";
    my_chdir 'contrib/src/xrc';
    my_system "make prefix=$tmpdir/install/wxWindows$prefix install";
    my_chdir '../stc';
    my_system "make prefix=$tmpdir/install/wxWindows$prefix install";
}

if( $build_wxperl ) {
    my_chdir "$tmpdir/build/wxPerl";
    my_system "rm -rf $tmpdir/install/wxPerl/*";
    my_system "make DESTDIR=$tmpdir/install/wxPerl install";
}

if( $build_perl ) {
    build_pkg( "Perl", $perl_version,
               "Perl $perl_version installer", "$tmpdir/install/perl",
               undef,
               "$tmpdir/build/dmg" );
}

if( $build_wxwindows ) {
    build_pkg( "wxWindows", $wxwin_version,
               "wxWindows $wxwin_version installer",
               "$tmpdir/install/wxWindows",
               undef,
               "$tmpdir/build/dmg" );
}

if( $build_wxperl ) {
    my $rsrc_dir = "$tmpdir/build/rsrc";

    mkdir $rsrc_dir;
    local *OUT;
    open OUT, "> $rsrc_dir/postflight";
    print OUT <<'EOT';
#!/bin/sh -e

PATH=/usr/local/bin:$PATH

for wxperl in /usr/bin/wxPerl /usr/local/bin/wxPerl; do
    if test -f $wxperl; then
        `wx-config --rezflags` $wxperl
    fi
done

exit 0
EOT
    close OUT;
    my_system "chmod +x $rsrc_dir/postflight";

    build_pkg( "wxPerl", $wxperl_version,
               "wxPerl $wxperl_version installer", "$tmpdir/install/wxPerl",
               $rsrc_dir,
               "$tmpdir/build/dmg" );
}

build_dmg( "wxPerl-$wxperl_version", "$tmpdir/build/dmg", "$tmpdir/build" );

my_system "cp $tmpdir/build/wxPerl-${wxperl_version}.dmg $distribution_dir";

sub build_pkg {
    my( $name, $version, $desc, $directory, $rsrc_dir, $destdir ) = @_;

    my_chdir "$tmpdir/build";
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

sub check_file($) {
  die "File not found '$_[0]'" unless -f $_[0];
}

sub check_files {
  check_file $wxmac_src;
  check_file $wxperl_src;
}
