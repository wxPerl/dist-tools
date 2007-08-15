package WxInfo;

use strict;
use File::Find;
use Fatal qw(open);

sub new {
  my( $ref, $path ) = @_;
  my $class = ref $ref || $ref;
  my $this = bless { PATH        => $path,
                     CLASSES     => {},
                     FUNCTIONS   => {},
                     INHERITANCE => {},
                     OK          => 0,
                   }, $class;

  die "Not a directory '$path'" unless -d $path;

  return $this;
}

sub _sharp_bang {
  my( $this, $package, $pl_package ) = @_;

  m/^\#\!sub\s+(\w+)/ and do {
    my $pl_method = "${pl_package}::${1}";
    my $method = "${package}::${1}";

    ${$this->{FUNCTIONS}}{$method} = $pl_method;
  } and return 1;
  m/^\#\!irrelevant\s+class\s+(\w+)/ and do {
    ${$this->{CLASSES}}{$1} = 'irrelevant';
  } and return 1;
  m/^\#\!equivalent\s+class\s+(\w+)\s+(.*)$/ and do {
    ${$this->{CLASSES}}{$1} = 'equivalent ' . $2;
  } and return 1;
  return 0;
}

sub do_scan_pm {
  my $this = shift;
  my $fh = shift;
  my( $pl_classes, $pl_funcs, $pl_inheritance ) =
    @{$this}{'CLASSES','FUNCTIONS','INHERITANCE'};
  my( $package, $pl_package );

  while( <$fh> ) {
    m/^package\s+([\w\:]+)\s*\;/ and do {
      $pl_package = $package = $1;
      $package =~ s/^Wx::/wx/;
      ${$pl_classes}{$package} = $pl_package;
      if( /\@ISA\s*=\s*qw\(Wx::(\S+)\)/ ) {
          ${$pl_inheritance}{substr $pl_package, 4}->{$1}++;
      }
      next;
    };
    m/\@ISA = qw\(Wx::(\S+)\)/ and do {
        ${$pl_inheritance}{substr $pl_package, 4}->{$1}++;
    };
    _sharp_bang( $this, $package, $pl_package ) and next;
    m/^sub\s*(\w+)/ and do {
      my $m = $1;
      my $pl_method = "${pl_package}::${m}";

      $m = $package if $m eq 'new';
      my $method = "${package}::${m}";

      ${$pl_funcs}{$method} = $pl_method;
      next;
    };
  }
}

sub do_scan_xs {
  my $this = shift;
  my $fh = shift;
  my( $pl_classes, $pl_funcs, $pl_inheritance ) =
    @{$this}{'CLASSES','FUNCTIONS','INHERITANCE'};

  my( $package, $pl_package );
  my $module_seen = 0;

  while( <$fh> ) {
    # added by BKE (bke@bkecc.com) - 09/02/2003
    # must be done before $module_seen check
    m/I\(\s*(.+?),\s*(.+?)\s*\)/ and do {

      # the conditional part of conditional inheritance is not
      # taken into account
      # for example:
      #     #if HAS_TLW
      #         I( Dialog,          TopLevelWindow )
      #      #else
      #        I( Dialog,          Panel )
      #     #endif
      # currently means that as far as WxInfo is concerned Dialog
      # inherits from both TopLevelWindow and Panel.
      # Is this a major problem?

      # used a hash to avoid duplicate entries
      ${$pl_inheritance}{$1}->{$2}++;
    };

    $module_seen = $module_seen || m/^MODULE=/;
    next unless $module_seen;

    m/PACKAGE=([\w\:]+)/ and do {
      $pl_package = $package = $1;
      $package =~ s/^Wx::/wx/;
      ${$pl_classes}{$package} = $pl_package;
      next;
    };
    m/INCLUDE:\s+(.*)\|\s*$/ and do {
      my $cmd = $1;

      open my $in, $cmd . ' |';
      do_scan_xs( $this, $in );
      next;
    };
    _sharp_bang( $this, $package, $pl_package ) and next;
    m/^([\w\:]+)\(/ and do {
      ( my $m = $1 ) =~ s/^.*:://;
      my $pl_method = "${pl_package}::${m}";

      $m = $package if $m eq 'new';
      my $method = "${package}::${m}";

      ${$pl_funcs}{$method} = $pl_method;
      next;
    };
  }
}

sub _scan_source {
  my $this = shift;
  my( $pl_classes, $pl_funcs, $pl_inheritance ) =
    @{$this}{'CLASSES','FUNCTIONS','INHERITANCE'};

  my $wanted = sub {
    if( -d $_ && m{^(?:demo|build)$} ) {
      $File::Find::prune = 1;
    } else {
      $File::Find::prune = 0;
    }

    return unless -f $_;
    return unless m/\.xs$|\.pm$|\.h$|\.cpp$/i;
#    return unless m/Constant\.xs$/i;

    open my $in, "< $_";

    if( m/\.pm$/ ) {
      do_scan_pm( $this, $in );
    } elsif ( m/\.xs$/ ) {
      do_scan_xs( $this, $in );
    } elsif ( m/\.h$|\.cpp$/ ) {
      # do_scan_c( $this, $in );
    }
  };

  find( $wanted, $this->{PATH} );
  $this->{OK} = 1;
}

sub get_classes {
  my $this = shift;
  $this->_scan_source unless $this->{OK};

  return $this->{CLASSES};
}

sub get_methods {
  my $this = shift;
  $this->_scan_source unless $this->{OK};

  return $this->{FUNCTIONS};
}

# added by BKE (bke@bkecc.com) - 09/02/2003
sub get_inheritance {
  my $this = shift;
  $this->_scan_source unless $this->{OK};

  for my $class (keys %{$this->{INHERITANCE}}) {
    $this->enumerate_parents($class);
  }

  return $this->{INHERITANCE};
}

# added by BKE (bke@bkecc.com) - 09/02/2003
sub enumerate_parents {
  # before enumerate_parents runs:
  #     ${$this}{INHERITANCE}-> classA -> classB
  #                                       classC
  #                             classB -> classD
  #                                    -> classE
  #                             classD -> classF
  # after enumerate_parents runs:
  #     ${$this}{INHERITANCE}-> classA -> classB
  #                                       classC
  #                                       classD
  #                                       classE
  #                                       classF
  #                             classB -> classD
  #                                    -> classE
  #                                       classF
  #                             classD -> classF
  my $this = shift;
  my $class = shift;
  for my $parent (keys %{${$this}{INHERITANCE}->{$class}}) {
    if (defined ${$this}{INHERITANCE}->{$parent}) {
      $this->enumerate_parents($parent);
      for my $grand_parent (keys %{${$this}{INHERITANCE}->{$parent}}) {
        ${$this}{INHERITANCE}->{$class}->{$grand_parent}++;
      }
    }
  }
}

1;

# local variables:
# mode: cperl
# end:
