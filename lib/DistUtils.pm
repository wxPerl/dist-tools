package DistUtils;

use strict;
use base qw(Exporter);
use vars qw(@EXPORT);
use Carp;
use File::Spec::Functions qw(catfile catdir updir);

@EXPORT = qw(my_chdir my_system my_unlink
             is_wx24 is_wx26 extract check_file check_dir);

sub my_chdir($) {
    print "cd $_[0]\n";
    chdir $_[0] or croak "chdir '$_[0]': $!";
}

sub my_unlink($) {
    print "unlink $_[0]\n";
    unlink $_[0] or croak "unlink '$_[0]': $!";
}

sub my_system {
  my $ret;
  my $cmd = join ' ', @_;
  print $cmd, "\n";

  if( @_ > 1 ) { $ret = system @_ } else { $ret = system $_[0] }
  $ret and croak "system: $cmd";
}

sub is_wx24($) { die unless $_[0]->wxwin_version;
                 $_[0]->wxwin_version =~ m/^2.4/ }
sub is_wx26($) { die unless $_[0]->wxwin_version;
                 $_[0]->wxwin_version =~ m/^2.[56]/ }

sub extract {
  my $archive = shift;
  my @files = @_ ? @_ : ( '*' );
  local $_ = $archive;

  my $ex = join ' ', map { "\"$_\"" } @files;

  m/(?:\.tar.gz|\.tgz)$/ && do {
    my_system "gzip -cd $archive | tar -x -f - $ex";
    return;
  };
  m/(?:\.tar.bz2|\.tbz)$/ && do {
    my_system "bzip2 -cd $archive | tar -x -f - $ex";
    return;
  };
  m/\.zip$/ && do {
    my_system "unzip -o -q $archive $ex";
    return;
  };

  die "Unknown archive '$archive'";
}

sub check_file($) {
  die "File not found '$_[0]'" unless -f $_[0];
}

sub check_dir($) {
  die "Directory not found '$_[0]'" unless -d $_[0];
}

1;

# local variables:
# mode: cperl
# end:
