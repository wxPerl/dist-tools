#!/usr/bin/perl -w

use strict;
use vars qw($rpms @rpmpath $chroot);

###############
# configuration
###############
my $user = 'mbarbon';
my $wxpath = '/scratch/redhat';
my $wxver = '2.4.0';
###################
# end configuration
###################

my $file = shift;
do "chroot/$file.pl";
die unless $chroot;

my $uid = `id -u $user`; chomp $uid;
my $gid = `id -g $user`; chomp $gid;

# utility
my %rpms;

sub add_rpm($$) {
  my( $name, $file ) = @_;

  $rpms{$name} = $file;
}

sub get_rpm($) {
  exists $rpms{$_[0]} or die "RPM '$_[0]' not found";
  $rpms{$_[0]};
}

sub check_rpm($) {
  exists $rpms{$_[0]}
}

sub run($) {
  print $_[0], "\n";
  system $_[0] and die "Error executing command '$_[0]'";
}

# read rpm list
foreach my $rpmpath ( @rpmpath ) {
  foreach my $f ( glob "$rpmpath/*.rpm" ) {
    $f =~ m{^.*/([\w\.\+\-]+)-([\w\.]+)-([\w\.]+)\.(\w+)\.rpm$}
      or die "Unable to parse '$f'";

    next if $4 eq 'i686';
    add_rpm( $1, $f );
  }
}

# check all are available
my $all_ok = 1;
foreach my $r ( split /\n/, $rpms ) {
  next unless length $r;
  $r =~ s/--nodeps\s+//;
  foreach my $n ( split / /, $r ) {
    my $ok = check_rpm $n;
    $all_ok &&= $ok;
    print "$n not found\n" unless $ok;
  }
}
exit 1 unless $all_ok;

# prepare the chroot
run "mkdir -p $chroot/var/lib/rpm";
run "rpm --initdb --root='$chroot'";

# install RPMs
foreach my $r ( split /\n/, $rpms ) {
  next unless length $r;
  my $nodeps = $r =~ s/--nodeps\s+// ? '--nodeps' : '';
  my @inst = map { get_rpm $_ } split / /, $r;

  run "rpm -i $nodeps --root=$chroot @inst";
}

# install wxGTK RPMs
run "rpm -i --root=$chroot " . join ' ',
	    glob( "${wxpath}/wxGTK*${wxver}*" );

# add the user the RPMs will be created as
chroot $chroot or die "chroot: $!";
run "groupadd -g $gid $user";
run "useradd -g $gid -u $uid $user";

exit 0;
