package Wx::Base;

use strict;
use warnings;

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

1;
