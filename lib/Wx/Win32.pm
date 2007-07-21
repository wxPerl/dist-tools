package Wx::Win32;

use strict;
use warnings;
use base 'Wx::Base';
use DistUtils qw(extract my_chdir check_file my_system my_copy);
use File::Spec::Functions qw(catdir updir);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath rmtree);
use DistConfig;
use Text::Template;
use Config;

sub _fix_ppd {
      my( $ppd, $pack ) = @_;
      die $ppd unless -f $ppd;
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
    my $alien_version = $distconfig->alien_version;
    my $wxwin_version = $distconfig->wxwin_version;
    my $alien_directory = $distconfig->alien_directory;

    my $wxmsw_build = catdir( $temp_dir, 'wxMSW' );
    my $wxperl_build = catdir( $temp_dir, $wxperl_directory );
    my $alien_build = catdir( $temp_dir, $alien_directory );

    my $alien_ppm_suffix = 'win32'
      . ( $wxperl_unicode ? '-u' : '' )
        . "-$Config{version}";
    my $alien_ppd = "Alien-wxWidgets-${alien_version}.ppd";
    my $alien_ppm = "Alien-wxWidgets-${alien_version}-" .
      "wx-${wxwin_version}-${alien_ppm_suffix}.tar.gz";
    my $alien_ppm_archive = "Alien-wxWidgets-${alien_version}-" .
      "wxmsw${wxwin_version}-${alien_ppm_suffix}.zip";
    my $alien_dev_ppd = "Alien-wxWidgets-dev-${alien_version}.ppd";
    my $alien_dev_ppm = "Alien-wxWidgets-dev-${alien_version}-" .
      "wx-${wxwin_version}-${alien_ppm_suffix}.tar.gz";
    my $alien_dev_ppm_archive = "Alien-wxWidgets-dev-${alien_version}-" .
      "wxmsw${wxwin_version}-${alien_ppm_suffix}.zip";

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

    @{$self}{qw(wxmsw_build wxperl_build wxperl_ppm_suffix alien_build
                wxperl_ppd wxperl_ppm wxperl_ppm_archive
                wxperl_dev_ppd wxperl_dev_ppm wxperl_dev_ppm_archive
                alien_ppd alien_ppm alien_ppm_archive
                alien_dev_ppd alien_dev_ppm alien_dev_ppm_archive
                )} =
      ( $wxmsw_build, $wxperl_build, $wxperl_ppm_suffix, $alien_build,
        $wxperl_ppd, $wxperl_ppm, $wxperl_ppm_archive,
        $wxperl_dev_ppd, $wxperl_dev_ppm, $wxperl_dev_ppm_archive,
        $alien_ppd, $alien_ppm, $alien_ppm_archive,
        $alien_dev_ppd, $alien_dev_ppm, $alien_dev_ppm_archive,
        );
}

sub _new_env {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $alien_build = $self->alien_build;

    return ( %ENV,
             PERL5OPT          => "-Mblib=$alien_build\\blib",
             ALIEN_WX_PREFIXES => "C:\\Programmi\\Devel\\Perl\\ActivePerl\\58\\site\\lib\\Alien\\wxWidgets,$alien_build\\blib\\arch\\Alien\\wxWidgets",
             );
}

sub build_alien {
    my $self = shift;
    my $dc = $self->_distconfig;

    # check files
    check_file $dc->wxmsw_src;
    check_file $dc->wxperl_src;

    # prepare wxWidgets sources
    my_chdir $dc->temp_dir;

    my $uc = $dc->wxperl_unicode ? '-u' : '';
    my $archive = "a-wxMSW-" . $dc->wxwin_version . $uc . '.tar.gz';
    rmtree $self->alien_build;
    if( -f $archive ) {
        extract $archive;
    } else {
        my_chdir catdir( $self->alien_build, updir() );
        extract( $dc->alien_src );
        my_copy( $dc->wxmsw_src, $self->alien_build );

        my $uc = $dc->wxperl_unicode ? ' --unicode --mslu' :
                                       ' --no-unicode --no-mslu';

        my_chdir catdir( $self->alien_build );
        my_system "perl -MConfig_m Build.PL$uc --build_wx --build_wx_opengl --source=tar.bz2";
        my_system 'perl -MConfig_m Build';

        my_chdir $dc->temp_dir;
        my_system "tar cf - " . $self->_distconfig->alien_directory . " | gzip -9 > $archive";
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
    local %ENV = $self->_new_env;
    my $alien_blib = $self->alien_build . '\\' . 'blib';
    my $uc = $dc->wxperl_unicode ? ' --wx-unicode --wx-mslu' :
                                   ' --no-wx-unicode --no-wx-mslu';
    my $ver = " --wx-version=" . $dc->wxwin_version;
    my_chdir $self->wxperl_build;
    my_system "perl -Mblib=$alien_blib -MConfig_m Makefile.PL$uc$ver";
    my_system 'nmake test';
}

sub _fill_readme {
    my( $self, $package ) = @_;
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

sub package_alien {
    my $self = shift;
    my $dc = $self->_distconfig;

    my_chdir $self->alien_build;

    my_system 'perl -MConfig_m Build ppmdist';

    # fix archive name
    my $alien_ver = $self->_distconfig->alien_version;
    for my $data ( [ "Alien-wxWidgets-${alien_ver}.ppd", $self->alien_ppm ],
                   [ "Alien-wxWidgets-dev-${alien_ver}.ppd", $self->alien_dev_ppm ],
                   ) {
        _fix_ppd( @$data );
    }
    my $alien_version = $dc->alien_version;
    my $alien_ppm = $self->alien_ppm;
    my $data_dir = $dc->data_dir;
    my $distribution_dir = $dc->distribution_dir;
    my $alien_ppm_archive = $self->alien_ppm_archive;
    my $alien_ppd = $self->alien_ppd;
    my $alien_dev_ppm_archive = $self->alien_dev_ppm_archive;
    my $alien_dev_ppm = $self->alien_dev_ppm;
    my $alien_dev_ppd = $self->alien_dev_ppd;

    $self->_fill_readme( 'Alien-wxWidgets-' . $alien_version );
    my_system "rm -f $distribution_dir/${alien_ppm_archive}";
    my_system "mv Alien-wxWidgets-${alien_version}-ppm.tar.gz $alien_ppm";
    my_system "zip -0 $distribution_dir/${alien_ppm_archive} $alien_ppm $alien_ppd README.txt";

    $self->_fill_readme( 'Alien-wxWidgets-dev-' . $alien_version );
    my_system "rm -f $distribution_dir/${alien_dev_ppm_archive}";
    my_system "mv Alien-wxWidgets-dev-${alien_version}-ppm.tar.gz $alien_dev_ppm";
    my_system "zip -0 $distribution_dir/${alien_dev_ppm_archive} $alien_dev_ppm $alien_dev_ppd README.txt";
}

sub package_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;

    my_chdir $self->wxperl_build;

    local %ENV = $self->_new_env;

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

    $self->_fill_readme( 'Wx-' . $wxperl_version );
    my_system "rm -f $distribution_dir/${wxperl_ppm_archive}";
    my_system "mv Wx-${wxperl_version}-ppm.tar.gz $wxperl_ppm";
    my_system "zip -0 $distribution_dir/${wxperl_ppm_archive} $wxperl_ppm $wxperl_ppd README.txt";

    $self->_fill_readme( 'Wx-dev-' . $wxperl_version );
    my_system "rm -f $distribution_dir/${wxperl_dev_ppm_archive}";
    my_system "mv Wx-dev-${wxperl_version}-ppm.tar.gz $wxperl_dev_ppm";
    my_system "zip -0 $distribution_dir/${wxperl_dev_ppm_archive} $wxperl_dev_ppm $wxperl_dev_ppd README.txt";
}

sub install_wxperl {
    my $self = shift;
    my $dc = $self->_distconfig;
    my $distribution_dir = $self->_distconfig->distribution_dir;
    my $alien_ppm_archive = $self->alien_ppm_archive;
    my $alien_dev_ppm_archive = $self->alien_dev_ppm_archive;
    my $wxperl_ppm_archive = $self->wxperl_ppm_archive;
    my $wxperl_dev_ppm_archive = $self->wxperl_dev_ppm_archive;

    system 'ppm remove Wx-dev';
    system 'ppm remove Wx';
    system 'ppm remove Alien-wxWidgets-dev';
    system 'ppm remove Alien-wxWidgets';

    my_chdir $dc->temp_dir;
    my_system "rm -f *.ppd";
    extract "$distribution_dir/${wxperl_ppm_archive}";
    extract "$distribution_dir/${wxperl_dev_ppm_archive}";
    extract "$distribution_dir/${alien_dev_ppm_archive}";
    extract "$distribution_dir/${alien_ppm_archive}";
    my_system "ppm install " . $self->alien_ppd;
    my_system "ppm install " . $self->alien_dev_ppd;
    my_system "ppm install " . $self->wxperl_ppd;
    my_system "ppm install " . $self->wxperl_dev_ppd;
}

sub build_submodules {
    my( $self,  @modules ) = @_;
    my $wxperl_version = $self->_distconfig->wxperl_version;
    my $temp_dir = $self->_distconfig->temp_dir;

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
        my_system 'perl -MConfig_m Makefile.PL --extra-cflags=" -Os -g "';
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
