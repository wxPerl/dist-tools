package DistUtils;

use strict;
use base qw(Exporter);
use vars qw(@EXPORT);
use Carp;

@EXPORT = qw(my_chdir my_system catdir catfile updir
             is_wx23 is_wx22 extract);

sub my_chdir($) {
  chdir $_[0] or croak "chdir '$_[0]': $!";
}

sub my_system {
  my $ret;
  my $cmd = join ' ', @_;
  print $cmd, "\n";

  if( @_ > 1 ) { $ret = system @_ } else { $ret = system $_[0] }
  $ret and croak "system: $cmd";
}

sub catfile { File::Spec->catfile( @_ ) }
sub catdir { File::Spec->catdir( @_ ) }
sub updir { File::Spec->updir( @_ ) }

sub is_wx23() { die unless $DistConfig::wxwin_version;
                $DistConfig::wxwin_version =~ m/^2.[345]/ }
sub is_wx22() { die unless $DistConfig::wxwin_version;
                $DistConfig::wxwin_version =~ m/^2.2/ }

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

1;

# local variables:
# mode: cperl
# end:
