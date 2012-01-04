package Module::UseFrom;

use strict;
use warnings;

use Carp;
use Module::CoreList;
use ExtUtils::Installed;
use version 0.77;

use Devel::Declare ();

my $inst = ExtUtils::Installed->new();

our $verbose;
my %export_ok = (
  'use_from' => { const => \&rewrite_use_from },
  'use_if_installed' => { const => \&rewrite_use_if_installed },
);

######################
## utility functions

sub _my_warn {
  my $string = shift;
  if ($verbose) {
    if (ref $verbose) {
      $$verbose .= $string;
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

  return $version;
}

sub get_varref_by_name {
  my ($caller, $var) = @_;
  my $varname = $caller . '::' . $var;

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
  unless (keys $export) {
    $export->{'use_from'} = $export_ok{'use_from'};
  }

  my $caller = caller;

  Devel::Declare->setup_for( $caller, $export );

  foreach my $keyword (keys %$export) {
    no strict 'refs';
    *{$caller.'::'.$keyword} = sub {};
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

sub rewrite_use_if_installed {
  my $linestr = Devel::Declare::get_linestr;

  _my_warn "use_if_installed got: $linestr";

  my $caller = Devel::Declare::get_curstash_name;

  $linestr =~ s/use_if_installed\s+\$(\w+)(?:\s+([^\s;]+))?/
    my $name = $1;
    my $version = $2 || '';

    my $varref = get_varref_by_name($caller, $name);
    my $module = $$varref;

    my $return = 'use_if_installed;';

    if (1) { # to be replaced with test for available
      $return .= " use $module";
      $return .= " $version" if $version;
    }

    $return;
  /e;
  
  _my_warn "use_if_installed returned: $linestr";

  Devel::Declare::set_linestr($linestr);
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

Many people have written about Perl's problem of loading a module from a string. This module attempts to solve that problem in a safe and useful manner. Using the magic of L<Devel::Declare>, the contents of a variable are translated into a bareword C<use> statement. Since C<Module::UseFrom> leans on this, the safest of the loading mechanisms, it should be every bit as safe. 

Said a different way, the final result is a bareword C<use> statement, so even if the translations/hueristics used internally fail, the system is not exposed to the insecurities introduced when translating to C<require FILE> statments or wrapping in a string C<eval>. 

Further, C<Module::UseFrom> can do some rudimentary checking before writing the C<use> statement. Most usefully, it can be told only to write the C<use> statement if the module is installed or even of a high enough version. 

=head1 INSTALLATION

During installation, one may see warnings like C<Name "ExtUtils::Packlist::FY1" used only once: possible typo at ...>. This seems to be related to L<ExtUtils::Installed> bug L<50315|https://rt.cpan.org/Public/Bug/Display.html?id=50315>. A patch has been submitted which should fix it. It is not a concern and does not affect any functionality whatsoever, just ignore it.

=head1 FUNCTION C<use_from>

The function C<use_from> is the basic interface provided by C<Module::UseFrom>. It takes one argument, a variable, called WITHOUT round braces (see L</SYNOPSIS>). The variable can be a scalar, array, or hash (not a list), the usage for each of these forms will be discussed later.

Some things to keep in mind:

=over

=item *

The variable must come after C<use_from> on the same line. This is a limitation stemming from L<Devel::Declare>.

=item *

The C<use_from> injects a C<use> statement taking the place of the original call and variable. This means if anything exists on the same line, it is left intact (even the ending semicolon is not affected). This behavior is by design, allowing the user to pass version or import directives as if C<use_from $var> was simply a regular C<use Bareword::Module> statement. For an alternative method of passing these directives see L</HASH>.

=back

=head1 THE VARIABLE

Since L<Devel::Declare> and C<use> both do their work at compile-time, your variable must be populated by then. C<BEGIN> blocks allow you to do this. C<Module::UseFrom> examines the given variable's contents, therefore the variable must be accessible from outside the package, this usually will mean using an C<our> variable. See the L</SYNOPSIS> to see an example.

C<Module::UseFrom> will inspect the variable for information. This variable must be a simple Scalar, Array or (not quite as simple) Hash. Each usage will have slightly different effects.

=head2 SCALAR

The most basic usage is as follows

 use Module::UseFrom;
 BEGIN {
   our $var = 'Scalar::Util';
 }
 use_from $var; # use Scalar::Util;

If you need to import or specify a version, just do it as you would have if this was a simple C<use> call where your variable replaces the module.

 use Module::UseFrom;
 BEGIN {
   our $var = 'Scalar::Util';
 }
 use_from $var qw/dualvar/; # use Scalar::Util qw/dualvar/;

=head2 ARRAY

Rather than making repeated calls to C<use_from> (which is fine), a shortcut is to pass an array which contains multiple module names. These will be translated to muliple C<use> directives. The last one will not be terminated, so conceivably this mechanism can be used to pass additional arguments to the last module in the array. Rather than do this though, check out the more useful L</HASH> type of calling when doing this. 

 use Module::UseFrom;
 BEGIN {
   our @var = qw'Scalar::Util List::Util';
 }
 use_from @var; # use Scalar::Util; use List::Util;

=head2 HASH

When called with a hash, the interface suddenly becomes a little more flexible. The keys are always the module to be used.

=head3 SIMPLE SCALAR

If the value is a simple scalar it is interpreted as a version directive. Use C<0> to allow any version (and in fact not even write the version to the C<use> directive).

=head3 ARRAY REFERENCE

If the value is an array reference, the elements are interpreted as import directives. These must (for now) be simple strings, not object/references etc. These are written out as a single quoted list, i.e. C<('item0', 'item1', ..., 'itemN')>.

=head3 HASH REFERENCE

If the value is a hash reference, the mechanism is the most flexible. This may contain the keys C<version> and C<import> which behave just like the two previous calling types (taking a scalar and an array reference repectively). In fact this calling style is used internally by the L</"SIMPLE SCALAR"> and L</"ARRAY REFERENCE"> types anyway. 

Further it also can take the key C<check_installed> with a true value. When this is done the module will only be written to a C<use> statement if L<Module::CoreList> or C<ExtUtils::Install> can find them. This prevents the embarrassing C<not found in @INC> errors when the module isn't installed; of course this means that it will not be loaded at all, so only use this functionality when it is deserved. To check if the module was loaded, C<Module::UseFrom> adds the key C<found_version> which contains the imformation that the aforementioned modules obtained in checking for the module. If the module isn't loaded then C<found_module> will be zero. N.B. if you intend to inspect your variable after wards you might need to declare it before the C<BEGIN> block.

Finally, if a C<version> and C<check_installed> are both specified and the module is installed but of insufficient version, the C<use> directive will not be writte, just as in the C<check_installed> scenario.

 use Module::UseFrom;
 our %var;
 BEGIN {
   %var = (
     'Carp' => {
       check_installed => 1,
       version => 0.01,
       'import' => [ qw/carp croak/ ]
     },
   );
 }
 use_from %var; # use Carp 0.01 ('carp', 'croak');
 print $var{Carp}{found_version}; # prints version of Carp found by Module::CoreList

=head1 OPTIONS

C<Module::UseFrom> has a few options, controlled by package variables. These also must be inside a C<BEGIN> block, so that they are set in time to be useful.

=head2 C<$Module::UseFrom::verbose>

When set to a true value, some additional information is printed to C<STDERR> (via C<warn>). In the special case that it is set to a reference to a scalar, the information is kept in that scalar rather than printing.

=head2 C<$Module::UseFrom::check_installed>

When set to a true value, all modules inspected by C<use_from> are treated as though the C<check_installed> option from L</"HASH REFERENCE"> was enabled, even if using the L</SCALAR> and L</ARRAY> forms.

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Module-UseFrom>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


