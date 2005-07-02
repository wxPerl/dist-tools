package Wx::Win32;

use strict;
use warnings;
use base 'Wx::Base';
use DistUtils qw(extract my_chdir check_file my_system is_wx24 is_wx26);
use File::Spec::Functions qw(catdir updir);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath rmtree);
use DistConfig;
use Text::Template;
use Config;

sub _fix_ppd {
      my( $ppd, $pack ) = @_;
      my_system qq{perl -i.bak -p -e "s#<CODEBASE\\s+HREF=\\"\\S*\\"\\s+/>#<CODEBASE HREF=\\"${pack}\\" />#;" $ppd};
      if( $] >= 5.008 ) {
          my_system qq{perl -i.bak -p -e "s#-multi-thread(?!-5.8)#-multi-thread-5.8#;" $ppd};
      }
}

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub set_options {
    my( $self, %args ) = @_;

    my $distconfig = DistConfig->new( $args{config}, '' );

    $self->{distconfig} = $distconfig;

    my $temp_dir = $distconfig->temp_dir;
    my $wxperl_directory = $distconfig->wxperl_directory;
    my $wxperl_unicode = $distconfig->wxperl_unicode;
    my $wxperl_version = $distconfig->wxperl_version;
    my $wxwin_version = $distconfig->wxwin_version;

    my $wxmsw_build = catdir( $temp_dir, 'wxMSW' );
    my $wxperl_build = catdir( $temp_dir, $wxperl_directory );
    my $wxperl_ppm_suffix = 'win32'
      . ( $wxperl_unicode ? '-u' : '' )
        . "-$Config{version}";
    my $wxperl_ppd = "Wx-${wxperl_version}.ppd";
    my $wxperl_ppm = "wxPerl-${wxperl_version}-" .
      "wx-${wxwin_version}-${wxperl_ppm_suffix}.tar.gz";
    my $wxperl_ppm_archive = "Wx-${wxperl_version}-" .
      "wxmsw${wxwin_version}-${wxperl_ppm_suffix}.zip";
    my $wxperl_dev_ppd = "Wx-dev-${wxperl_version}.ppd";
    my $wxperl_dev_ppm = "wxPerl-dev-${wxperl_version}-" .
      "wx-${wxwin_version}-${wxperl_ppm_suffix}.tar.gz";
    my $wxperl_dev_ppm_archive = "Wx-dev-${wxperl_version}-" .
      "wxmsw${wxwin_version}-${wxperl_ppm_suffix}.zip";

    @{$self}{qw(wxmsw_build wxperl_build wxperl_ppm_suffix wxperl_ppd
                wxperl_ppm wxperl_ppm_archive wxperl_dev_ppd wxperl_dev_ppm
                wxperl_dev_ppm_archive)} =
      ( $wxmsw_build, $wxperl_build, $wxperl_ppm_suffix, $wxperl_ppd,
        $wxperl_ppm, $wxperl_ppm_archive, $wxperl_dev_ppd, $wxperl_dev_ppm,
        $wxperl_dev_ppm_archive,
      );
}

sub build_wxwidgets {
    my $self = shift;
    my $dc = $self->_distconfig;

    # check files
    check_file $dc->wxmsw_src;
    foreach my $i ( @{$dc->wxmsw_patches} ) {
        check_file $i;
    }
    check_file $dc->wxperl_src;

    # prepare wxWidgets sources
    my_chdir $dc->temp_dir;

    my $uc = $dc->wxperl_unicode ? '-u' : '';
    my $archive = "wxMSW-" . $dc->wxwin_version . $uc . '.tar.gz';
    if( -f $archive ) {
        rmtree $self->wxmsw_build;
        extract $archive;
    } else {
        rmtree $self->wxmsw_build;
        mkpath $self->wxmsw_build;
        my_chdir $self->wxmsw_build;
        my $wad = $dc->wxmsw_directory;

        if( length $wad ) {
            extract( $dc->wxmsw_src,
                     "$wad/contrib/*", "$wad/src/*", "$wad/lib/*",
                     "$wad/include/*", "$wad/art/*",
                     ( is_wx26( $dc ) ? ( "$wad/build/*",
                                          "$wad/samples/minimal/*",
                                          "$wad/samples/sample.*" ) : () ) );
            my_system "mv $wad/* .";
            my_system "rmdir $wad";
        } else {
            extract( $dc->wxmsw_src, "contrib/*", "src/*",
                     "lib/*", "include/*" );
            extract( $dc->wxmsw_src, "art/*" );
        }

        foreach my $i ( @{$dc->wxmsw_archives} ) { extract( $i, "*" ) }
        my_system "cp -f include/wx/msw/setup0.h include/wx/msw/setup.h"
          if -f "include/wx/msw/setup0.h";
        my_system "rm -f src/makeg95.env~";
        foreach my $i ( @{$dc->wxmsw_patches} ) {
            my_system "cat $i | patch -b -p0";
        }

        # build wxWidgets
        local $ENV{WXDIR} = $self->wxmsw_build;
        local $ENV{WXWIN} = $self->wxmsw_build;
        my $opt = $dc->wxperl_unicode ? ' UNICODE=1 MSLU=1' :
                                        ' UNICODE=0 MSLU=0';
        my $makefile;

        if( is_wx26( $dc ) ) {
            $opt .= ' BUILD=release CXXFLAGS=" -Os -DNO_GCC_PRAGMA " SHARED=1';
            $makefile = 'makefile.gcc';
            my_chdir catdir( $self->wxmsw_build, 'build', 'msw' );
        } else {
            $opt .= ' FINAL=1 CXXFLAGS=-Os WXMAKINGDLL=1';
            $makefile = 'makefile.g95';
            my_chdir catdir( $self->wxmsw_build, 'src', 'msw' );
        }
        my_system "make -f $makefile all$opt";
        if( is_wx24( $dc ) ) {
            my_chdir catdir( $self->wxmsw_build, 'contrib', 'src', 'xrc' );
            my_system "make -f makefile.g95 all$opt WXUSINGDLL=1";
        }
        if( is_wx26( $dc ) ) {
            my_chdir catdir( $self->wxmsw_build, 'contrib', 'build', 'stc' );
        } else {
            my_chdir catdir( $self->wxmsw_build, 'contrib', 'src', 'stc' );
        }
        # fine (if ugly) for both 2.4 and 2.5
        my_system "make -f $makefile all$opt WXUSINGDLL=1";

        my_chdir $dc->temp_dir;
        my_system "tar cf - wxMSW | gzip -9 > $archive";
    }
}

sub build_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    # prepare wxPerl sources
    rmtree $self->wxperl_build;
    mkpath $self->wxperl_build;
    my_chdir catdir( $self->wxperl_build, updir() );
    extract( $dc->wxperl_src );

    # build wxPerl
    local $ENV{WXDIR} = $self->wxmsw_build;
    local $ENV{WXWIN} = $self->wxmsw_build;
    my $np;
    if( is_wx26( $dc ) ) {
        $np = catdir( $self->wxmsw_build, 'lib', 'gcc_dll' ) . ';'
              . $ENV{PATH};
    } else {
        $np = catdir( $self->wxmsw_build, 'lib' ) . ';' . $ENV{PATH};
    }
    local $ENV{PATH} = $np;
    my $uc = $dc->wxperl_unicode ? ' --unicode --mslu' : ' ';
    my_chdir $self->wxperl_build;
    my_system "perl -MConfig_m Makefile.PL$uc ";
    my_system 'nmake test';
}

sub package_wxwidgets {
}

sub _fill_readme {
    my( $self, $is_dev ) = @_;
    my $package = 'Wx' . ( $is_dev ? '-dev' : '' ) . '-' .
      $self->_distconfig->wxperl_version;
    my $data_dir = $self->_distconfig->data_dir;

    unlink 'README.txt';

    my $tmpl = Text::Template->new( TYPE       => 'FILE',
                                    SOURCE     => "$data_dir/README.txt",
                                    DELIMITERS => [ '<%', '%>' ] );

    open my $readme_fh, "> README.txt";
    die "Error while filling template: $Text::Template::ERROR"
      unless $tmpl->fill_in( OUTPUT => $readme_fh,
                             HASH => { package => $package,
                                     } );
    close $readme_fh;
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    my_chdir $self->wxperl_build;

    my_system 'nmake ppmdist';
    # fix archive name
    for my $data ( [ $self->wxperl_ppd, $self->wxperl_ppm ],
                   [ $self->wxperl_dev_ppd, $self->wxperl_dev_ppm ] ) {
        _fix_ppd( @$data );
    }
    my $wxperl_version = $dc->wxperl_version;
    my $wxperl_ppm = $self->wxperl_ppm;
    my $data_dir = $dc->data_dir;
    my $distribution_dir = $dc->distribution_dir;
    my $wxperl_ppm_archive = $self->wxperl_ppm_archive;
    my $wxperl_ppd = $self->wxperl_ppd;
    my $wxperl_dev_ppm_archive = $self->wxperl_dev_ppm_archive;
    my $wxperl_dev_ppm = $self->wxperl_dev_ppm;
    my $wxperl_dev_ppd = $self->wxperl_dev_ppd;

    $self->_fill_readme( 0 );
    my_system "mv Wx-${wxperl_version}-ppm.tar.gz $wxperl_ppm";
    my_system "zip -0 $distribution_dir/${wxperl_ppm_archive} $wxperl_ppm $wxperl_ppd README.txt";

    $self->_fill_readme( 1 );
    my_system "mv Wx-dev-${wxperl_version}-ppm.tar.gz $wxperl_dev_ppm";
    my_system "zip -0 $distribution_dir/${wxperl_dev_ppm_archive} $wxperl_dev_ppm $wxperl_dev_ppd README.txt";
}

sub install_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $distribution_dir = $self->_distconfig->distribution_dir;
    my $wxperl_version = $self->_distconfig->wxperl_version;
    my $wxperl_ppm_archive = $self->wxperl_ppm_archive;
    my $wxperl_dev_ppm_archive = $self->wxperl_dev_ppm_archive;

    system 'ppm remove Wx-dev';
    system 'ppm remove Wx';
    my_chdir $dc->temp_dir;
    my_system "rm -f *.ppd";
    extract "$distribution_dir/${wxperl_ppm_archive}";
    extract "$distribution_dir/${wxperl_dev_ppm_archive}";
    my_system "ppm install Wx-${wxperl_version}.ppd";
    my_system "ppm install Wx-dev-${wxperl_version}.ppd";
}

sub build_submodules {
    my( $self,  @modules ) = @_;
    my $wxperl_version = $self->_distconfig->wxperl_version;
    my $temp_dir = $self->_distconfig->temp_dir;
    local $ENV{WXDIR} = $self->wxmsw_build;
    local $ENV{WXWIN} = $self->wxmsw_build;
    local $ENV{PATH} = catdir( $self->wxmsw_build, 'lib' ) . ';' . $ENV{PATH};

    my $wx_v = `perl -MWx=$wxperl_version -e "print Wx::wxVERSION();"`;
    my $wx_u = `perl -MWx=$wxperl_version -e "print Wx::wxUNICODE();"`;
    chomp $wx_v; chomp $wx_u;

#    eval "use Wx $wxperl_version"; die $@ if $@;

    my $wx_version = join '.',
                 map { eval "$_ + 0" }
                 ( ( $wx_v =~ m/(\d+)\.(\d{3})?(\d{3})?/ ), 0, 0, 0 )
                 [0 .. 2];
    my $package_ppm_suffix = ( $wx_u ? '-u' : '' )
                           . "-$Config{version}";

    foreach my $module ( @modules ) {
        my $package_src = $self->_distconfig->get_module_src( $module );
        my $package_directory = basename( $package_src );
        $package_directory =~ s/\.(tar\.gz|zip|tgz)$//;
        my $package_base = $package_directory; $package_base =~ s/\-[\d\.]+$//;
        my $package_build = catdir( $temp_dir, $package_directory );
        my $package_ppd = "${package_base}.ppd";
        my $package_ppm = "${package_base}-ppm.tar.gz";
        my $package_ppm_archive = "${package_directory}-" .
                              "wxperl${wxperl_version}-" .
                              "wxmsw${wx_version}${package_ppm_suffix}.zip";
        my $destination_dir = catdir( dirname( $package_src ),
                                      $wxperl_version );

        # check source
        check_file $package_src;

        # extract source
        rmtree $package_build;
        mkpath $package_build;
        my_chdir catdir( $package_build, updir() );
        extract( $package_src );

        # build module
        my_chdir $package_build;
        my_system "perl -MConfig_m Makefile.PL";
        my_system 'nmake test';

        # create ppm
        my_system 'nmake ppd';
        my_system "tar cf - blib | gzip -9 > $package_ppm";
        _fix_ppd( $package_ppd, $package_ppm );
        my_system "zip -0 $destination_dir/${package_ppm_archive} $package_ppm $package_ppd";
    }
}

sub make_dist {
}

1;
