#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::RealBin/lib";
use File::Spec;
use File::Basename;
use WxInfo;

my $dest = pop @ARGV;
my( @patterns ) = @ARGV;
my $wxperl = '../wxPerl';
use vars qw(%pl_classes %pl_funcs %pl_inheritance);

scan_wxperl();
process_tex();

exit 0;

sub process_tex {
  open my $log, ">", "copy.log";
  foreach my $f ( map { glob } @patterns ) {
    my $fname = basename( $f );
    my $destfile = File::Spec->catfile( $dest, $fname );
    my $unimplemented_class = 0;

    local( *IN, *OUT );
    open IN, "< $f" or die "open '$f': $!";
    open OUT, "> $destfile" or die "open '$destfile': $!";
    binmode OUT;

    while( <IN> ) {
      m/\\class{([\w<>]+)}/ and do {
        my $class = $1;
        $class =~ s/\<\w+\>//;
        print OUT $_;
        if( !exists $pl_classes{$class} ) {
          print $log "Class $class is not implemented\n";
          print OUT "\n\\perlnote{This class is not implemented in wxPerl}\n";
          $unimplemented_class = 1;
        } elsif( $pl_classes{$class} eq 'irrelevant' ) {
          print OUT "\n\\perlnote{This class is not relevant to wxPerl}\n";
          $unimplemented_class = 1;
        } elsif( $pl_classes{$class} =~ /^equivalent / ) {
          my $equiv = $pl_classes{$class};
          print OUT "\n\\perlnote{This class is $equiv}\n";
          $unimplemented_class = 1;
        } else {
          $unimplemented_class = 0;
        }
        next;
      };
      # edited by BKE (bke@bkecc.com) - 09/02/2003
      m/\\membersection{(\w+\:+[\w\:]+)}/ and do {
        print OUT $_;
        if( !$unimplemented_class && !exists $pl_funcs{$1} ) {
          # if a function is missing check inherited functions
          my $inherited = '';
          my $function_name = $1;
          ( my $class_name = $1 ) =~ s/^wx(.+?)::.*/$1/;
          if ( defined $pl_inheritance{$class_name} ) {
            for my $parent ( keys %{$pl_inheritance{$class_name}} ) {
              ( my $parent_function_name = $function_name ) =~ s/$class_name/$parent/;
              if ( exists $pl_funcs{$parent_function_name} ) {
                $inherited = $parent_function_name and last;
              }
            }
          }
          # right now noting inheritance in the docs for testing.
          # keep doing this?
          if ($inherited) {
#            print OUT "\n\\perlnote{This method is inherited from $inherited.}\n";
          }
          else {
            print $log "Function $function_name is not implemented\n"
                unless $function_name =~ /^(?:wxDateTime|wxDateSpan|wxTimeSpan)::/;
            print OUT "\n\\perlnote{This method is not implemented in wxPerl}\n";
          }
        }
        next;
      };

      # default
      print OUT $_;
    }
  }
}

sub scan_wxperl {
  my $info = WxInfo->new( $wxperl );

  *pl_classes = $info->get_classes;
  *pl_funcs = $info->get_methods;
  *pl_inheritance = $info->get_inheritance;
}

exit 0;

# local variables:
# mode: cperl
# end:
