package Wx::Base;

use strict;
use warnings;
use Net::SCP qw();
use Net::SSH qw(ssh);
use File::Temp;

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

my $ssh = 'C:\\Programmi\\Utility\\Cygwin\\bin\\ssh.exe';
my $scp = 'C:\\Programmi\\Utility\\Cygwin\\bin\\scp.exe';

$Net::SSH::ssh = $ssh;
$Net::SCP::scp = $scp;
# $Net::SCP::DEBUG = 1;

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub _put_file {
    my( $self, $file, $name ) = @_;
    my $scp = Net::SCP->new( $self->_distconfig->remote_host,
                             $self->_distconfig->remote_user ) or die $!;

    $file =~ s!^(\w):!/cygdrive/$1!; $file =~ tr!\\!/!;
    $scp->put( $file, $name ) or die $scp->{errstr};
}

sub _get_file {
    my( $self, $file, $name ) = @_;
    my $scp = Net::SCP->new( $self->_distconfig->remote_host,
                             $self->_distconfig->remote_user ) or die $!;

    $name =~ s!^(\w):!/cygdrive/$1!; $name =~ tr!\\!/!;
    $scp->get( $file, $name ) or die $scp->{errstr};
}

sub _put_string {
    my( $self, $string, $name ) = @_;
    my $tmp = File::Temp->new( SUFFIX => '.sh' );
    binmode $tmp;

    print $tmp $string;
    $self->_put_file( $tmp->filename, $name );
}

sub _exec_string {
    my( $self, $string ) = @_;
    $self->_put_string( $string, 'tmp.sh' );

    ssh( ( sprintf "%s\@%s", $self->_distconfig->remote_user,
                             $self->_distconfig->remote_host ),
         'sh', 'tmp.sh' );
}

sub _exec_command {
    my( $self, $host, $user, @data ) = @_;

    ssh( "$user\@$host", @data );
}

1;
