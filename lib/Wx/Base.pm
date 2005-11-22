package Wx::Base;

use strict;
use warnings;
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

sub is_win32() { $^O =~ /MSWin/i }

my $ssh = is_win32 ? 'C:\\Programmi\\Utility\\Cygwin\\bin\\ssh.exe' : 'ssh';
my $scp = is_win32 ? 'C:\\Programmi\\Utility\\Cygwin\\bin\\scp.exe' : 'scp';
my( $once_scp, $once_ssh );

sub _require_ssh {
    return if $once_ssh;
    require Net::SSH;

    $Net::SSH::ssh = $ssh;
    $once_ssh = 1;
}

sub _require_scp {
    return if $once_scp;
    require Net::SCP;

    $Net::SCP::scp = $scp;
    # $Net::SCP::DEBUG = 1;
    $once_scp = 1;
}

sub new {
    my $class = shift;

    return bless { }, $class;
}

sub _put_file {
    _require_scp();

    my( $self, $file, $name ) = @_;
    my $scp = Net::SCP->new( $self->_distconfig->remote_host,
                             $self->_distconfig->remote_user ) or die $!;

    $file =~ s!^(\w):!/cygdrive/$1!; $file =~ tr!\\!/!;
    if( $^O =~ /MSWin/i ) {
	$scp->put( $file, $name ) or die $scp->{errstr};
    } else {
	foreach my $f ( glob $file ) {
	    $scp->put( $f, $name ) or die $scp->{errstr};
	}
    }
}

sub _get_file {
    _require_scp();

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
    _require_ssh();

    my( $self, $string ) = @_;
    $self->_put_string( $string, 'tmp.sh' );

    Net::SSH::ssh( ( sprintf "%s\@%s", $self->_distconfig->remote_user,
                                       $self->_distconfig->remote_host ),
                   'sh', 'tmp.sh' );
}

sub _exec_command {
    _require_ssh();

    my( $self, $host, $user, @data ) = @_;

    Net::SSH::ssh( "$user\@$host", @data );
}

1;
