#!/usr/bin/perl -w

use strict;
################
# configuration
################
my $user = 'mbarbon';
my $chroot = '/home/mbarbon/chroot/debian';
my $mirror = 'http://www2.rbnet.it/debian';
my $suite = 'woody';
my $suite2 = 'woody';
####################
# end configuration
####################

# utility
my $uid = `id -u $user`; chomp $uid;
my $gid = `id -g $user`; chomp $gid;

sub run($) {
    print $_[0], "\n";
    system $_[0] and die "Error executing command '$_[0]'";
}

# prepare the chroot

run "mkdir -p $chroot";
run "debootstrap $suite $chroot $mirror";

chroot $chroot or die "chroot: $!";

open OUT, "> /etc/apt/sources.list" or die "open: $!";
print OUT "deb $mirror $suite2 main\n";
close OUT;

run "mount -t proc /proc /proc";
run "apt-get -y remove at cron exim lilo logrotate mailx ppp";
run "umount /proc";

run "apt-get update";
run "apt-get -y upgrade";

my $apt = 'apt-get -y install';
run "$apt build-essential";
run "$apt debhelper fakeroot";
run "$apt libwxgtk2.2-dev libwxgtk2.2-contrib-dev";
run "$apt bison flex bzip2 unzip";

run "groupadd -g $gid $user";
run "useradd -u $uid -g $gid $user";
run "mkdir /home/$user";
run "chown $uid.$gid /home/$user";

exit 0;
