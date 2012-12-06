package Module::UseFrom;

use strict;
use warnings;

use v5.8.1;

use Carp;
use Module::CoreList;
use Scalar::Util qw/dualvar/;
use ExtUtils::Installed;
use version 0.77;

use Devel::Declare ();

my $inst = ExtUtils::Installed->new();

our $verbose;
my %export_ok = (
  'use_from' => { const => \&rewrite_use_from },
  'use_if_available' => { const => \&rewrite_use_if_available },
);

######################
## utility functions

sub _my_warn {
  my $string = shift;
  if ($verbose) {
    if ((ref $verbose || '') eq 'SCALAR') {
      $$verbose .= "$string\n";
    } else {
      warn $string;
    }
  }
}

sub find_module_version {
  my $module = shift;

  my $version = 
    eval { $inst->version($module) } ||
    exists $Module::CoreList::version{$]}{$module} 
      ? ( $Module::CoreList::version{$]}{$module} || 1e-7 )
      : 0;

  # some core module do not have version numbers, they are returned as 1e-7

  $version = version->parse($version);

  _my_warn $version ? "\tFound version $version" : "\tCouldn't find version info for $module!";

  return $version;
}

sub get_varref_by_name {
  my ($caller, $var) = @_;
  my $varname = $caller . '::' . $var;

  _my_warn "\tInvestigating package $caller for variable $caller, resolved as $varname";

  no strict 'refs';
  my $varref = 
    (defined ${$varname}) 
    ? \${$varname}
    : croak "Cannot access variable \$$varname";

  return $varref;
}

###########
## import

sub import {
  my $class = shift;

  # setup from explicit imports
  my $export = {};
  foreach my $keyword (@_) {

    # :all tag
    if ($keyword eq ':all') {
      $export = \%export_ok;
      last;
    }

    # check import is available
    unless ( exists $export_ok{$keyword} ) {
      carp "Keyword $keyword is not exported by Module::UseFrom";
      next;
    }

    # setup specific keyword
    $export->{$keyword} = $export_ok{$keyword};
  }

  # if called without explicit imports
  unless (keys %$export) {
    $export->{'use_from'} = $export_ok{'use_from'};
  }

  my $caller = caller;

  Devel::Declare->setup_for( $caller, $export );

  foreach my $keyword (keys %$export) {
    no strict 'refs';
    *{$caller.'::'.$keyword} = sub (@) {};
  }

}

##################
## rewrite rules

sub rewrite_use_from {
  my $linestr = Devel::Declare::get_linestr;

  _my_warn "use_from got: $linestr";

  my $caller = Devel::Declare::get_curstash_name;

  $linestr =~ s/use_from\s+\$(\w+)/
    my $varref = get_varref_by_name($caller, $1);
    my $module = $$varref;
    "use_from; use $module";
  /e;
  
  _my_warn "use_from returned: $linestr";

  Devel::Declare::set_linestr($linestr);
}

sub rewrite_use_if_available {
  my $linestr = Devel::Declare::get_linestr;

  _my_warn "use_if_available got: $linestr";

  my $caller = Devel::Declare::get_curstash_name;

  $linestr =~ s/use_if_available\s+\$(\w+)(\s+[^\s;]+)?/
    my $name = $1;
    my $version = $2;
    do_use_if_available($caller, $name, $version);
  /e;
  
  _my_warn "use_if_available returned: $linestr";

  Devel::Declare::set_linestr($linestr);
}

sub do_use_if_available {
  my ($caller, $name, $version) = @_;
  my $return = 'use_if_available ';

  my $varref = get_varref_by_name($caller, $name);
  my $module = $$varref;

  _my_warn "\tFound request for module $module";

  my $found_version = find_module_version($module);

  unless ($found_version) {
    my $dualvar = dualvar 0, $module;
    $$varref = $dualvar;
    return $return;
  }

  my $requested_version;
  if ($version) {
    $requested_version = eval { version->parse($version) };
    _my_warn "\tRequested version $requested_version";
  }

  if (defined $requested_version and $requested_version > $found_version) {
    _my_warn "\tInsufficient version found, skipping import!";
    my $dualvar = dualvar 0, $module;
    $$varref = $dualvar;
    return $return;
  }

  my $dualvar = dualvar $found_version->numify, $module;
  $$varref = $dualvar;

  $return .= "; use $module";
  $return .= $version if $version;

  return $return;
}

1;

__END__
__POD__

=head1 NAME

Module::UseFrom - Safe compile-time module loading from a variable

=head1 SYNOPSIS

 use Module::UseFrom;
 BEGIN {
   our $var = 'Scalar' . '::' . 'Util';
 }
 use_from $var; # use Scalar::Util;

=head1 DESCRIPTION

Many people have written about Perl's problem of loading a module from a string. This module attempts to solve that problem in a safe and useful manner. Using the magic of L<Devel::Declare>, the contents of a variable are translated into a bareword C<use> statement. Since C<Module::UseFrom> leans on this, the safest of the loading mechanisms, it should be every bit as safe. Even if the translations/heuristics used internally should fail, the system is not exposed to the insecurities introduced when translating to C<require FILE> statments or wrapping in a string C<eval>. 

Further, C<Module::UseFrom> can do some rudimentary checking before writing the C<use> statement. Most usefully, it can be told only to write the C<use> statement if the module is installed or even of a high enough version. 

=head1 FUNCTIONS 

C<Module::UseFrom> exports C<use_from> by default. Any of the following functions may be requested in the usual manner. The tag C<:all> will request them all.

=head2 use_from

The function C<use_from> is the basic interface provided by C<Module::UseFrom>. It takes one scalar variable, called WITHOUT round braces. C<Module::UseFrom> will inspect the variable for information. This variable must be a simple scalar (i.e. not a reference).

The most basic usage is as follows:

 use Module::UseFrom;
 BEGIN {
   our $var = 'Scalar::Util';
 }
 use_from $var; # use Scalar::Util;

If you need to import or specify a version, just do it as you would have if this was a simple C<use> call where your variable replaces the module:

 use Module::UseFrom;
 BEGIN {
   our $var = 'Scalar::Util';
 }
 use_from $var qw/dualvar/; # use Scalar::Util qw/dualvar/;

Some things to keep in mind:

=over

=item *

The variable must follow C<use_from> on the same line. This is a limitation stemming from L<Devel::Declare>.

=item *

The C<use_from> injects a C<use> statement taking the place of the original call and variable. This means if anything else exists on the same line or if the statement continues to further lines, it is left intact (even the ending semicolon is not affected). This behavior is by design, allowing the user to pass version or import directives as if C<use_from $var> was simply a regular C<use Bareword::Module> statement.

=item *

Since L<Devel::Declare> and C<use> both do their work at compile-time, your variable must be populated by then. C<BEGIN> blocks allow you to do this. 

=item *

C<Module::UseFrom> examines the given variable's contents, therefore the variable must be accessible from outside the package, this usually will mean using an C<our> variable.

=back

=head2 use_if_available

C<use_if_available> is called in the same way as C<use_from>, however unlike that function, it checks to see if the module is available before injecting the C<use> statement. Further if it detects a version declaration following the variable, it will only inject the C<use> statement if the version restriction can be satisfied.

To check if the module was C<use>ed, you may examine your original value in numeric context, which will contain the version as determined by L<Module::CoreList> or L<ExtUtils::Installed> (for core or non-core modules respectively) or C<0> if the module is not found.

 use Module::UseFrom 'use_if_available';
 our $var; # declared outside BEGIN for later inspection
 BEGIN {
   $var = 'Scalar::Util';
 }
 use_if_available $var 999 qw/reftype/; # Scalar::Util is not loaded

 die "I guess I really wanted $var" unless $var > 0;

Unlike C<use_from>, which naively injects the proper C<use> statement in-place, C<use_if_available> is smarter and will inject a list-prototyped no-op call in front of any import list should the module not be available or not of the proper version. If you don't know what this means, don't fret, just know that C<use_if_available> behaves as you think it should.

=head1 VERBOSE OUTPUT

Verbose output is controlled by the package variable C<$Module::UseFrom::verbose>.

When set to a true value, some additional information is printed to C<STDERR> (via C<warn>). In the special case that it is set to a reference to a scalar, the information is kept in that scalar rather than printing. Activating this feature will most likely need to be performed inside a C<BEGIN> block, so that it is set in time to be useful.

=head1 INSTALLATION ISSUES

During installation, one may see warnings like C<Name "ExtUtils::Packlist::FY1" used only once: possible typo at ...>. This seems to be related to L<ExtUtils::Installed> bug L<50315|https://rt.cpan.org/Public/Bug/Display.html?id=50315>. A L<patch|https://rt.perl.org/rt3//Public/Bug/Display.html?id=107410> has been accepted which should fix it. It is not a concern and does not affect any functionality whatsoever, just ignore it.

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Module-UseFrom>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


