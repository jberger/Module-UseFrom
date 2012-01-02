package Module::UseFrom;

use strict;
use warnings;

use Carp;
use Module::CoreList;
use ExtUtils::Installed;
use version 0.77;

use Devel::Declare ();

my $inst = ExtUtils::Installed->new();
our $verbose = 0;
our $check_installed = 0;

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

sub import {
  my $class = shift;
  my $opts = shift;

  $verbose = $opts->{verbose} || 0;
  $check_installed = $opts->{check_installed} || 0;

  my $caller = caller;

  Devel::Declare->setup_for(
      $caller,
      { 'use_from' => { const => \&rewrite_use_from } }
  );
  no strict 'refs';
  *{$caller.'::use_from'} = sub {};

}

sub rewrite_use_from {
  my $linestr = Devel::Declare::get_linestr;

  _my_warn "Got: $linestr";

  my $caller = Devel::Declare::get_curstash_name;

  $linestr =~ s/use_from\s+([\$\@\%]{1})(\w+)/
    my $sigil = $1;
    my $var = $2;
    gen_replacement($caller, $sigil, $var);
  /e;
  
  _my_warn "Rewritten: $linestr";

  Devel::Declare::set_linestr($linestr);
}

sub gen_replacement {
  my ($caller, $sigil, $var) = @_;

  my $varname = $caller . '::' . $var;

  my $new_statement = 'use_from; ';

  no strict 'refs';
  if ($sigil eq '$') {
    my $module = 
      (defined ${$varname}) 
      ? ${$varname}
      : croak "Cannot access variable \$$varname";
    $new_statement .= gen_use_statement($module);
  } elsif ($sigil eq '@') {
    my @modules = 
      (scalar @{$varname}) 
      ? @{$varname}
      : croak "Cannot access variable \@$varname";
  
    my @statements = map { gen_use_statement($_) || () } @modules;

    $new_statement .= join('; ', @statements);
  } elsif ($sigil eq '%') {
    my %modules = 
      (scalar keys %{$varname}) 
      ? %{$varname}
      : croak "Cannot access variable \%$varname";

    my @statements;

    foreach my $module (keys %modules) {
      my $reftype = ref $modules{$module};

      my $statement;
      if ($reftype eq 'HASH') {
        $statement = gen_use_statement($module, $modules{$module});
      } elsif ($reftype eq 'ARRAY') {
        $statement = gen_use_statement(
          $module,
          { 'import' => $modules{$module} }
        );
      } else {
        $statement = gen_use_statement(
          $module,
          { 'version' => $modules{$module} }
        );
      }

      push @statements, $statement if $statement;
    }

    $new_statement .= join('; ', @statements);
  }

  return $new_statement;
}

sub gen_use_statement {
  my ($module, $opts) = @_;

  $opts ||= {};

  my $check = $check_installed || $opts->{check_installed};
  my $req_version = $opts->{version} || 0;

  my $found_version;
  if ($check) {
    $found_version = 
      eval { $inst->version($module) } ||
      exists $Module::CoreList::version{$]}{$module} 
        ? ( $Module::CoreList::version{$]}{$module} || 'no version') 
        : undef;

    return '' unless $found_version;

    

    if ($req_version) {
      my $rv = version->parse($req_version);
      my $fv = version->parse($found_version);

      return '' unless ($fv >= $rv);
    }

  }

  my $return = "use $module";

  if ($req_version) {
    $return .= " $req_version";
  }

  if (ref $opts->{'import'} and @{ $opts->{'import'} }) {
    $return .= q/ ('/ . join( q/', '/, @{ $opts->{'import'} } ) . q/')/;
  }

  if (wantarray) {
    return ($return, $found_version);
  } else { 
    return $return;
  }
}

1;

__END__
__POD__

=head1 NAME

Module::UseFrom - Safe compile-time module loading from a variable

=head1 SYNOPSIS

 use Module::UseFrom
 BEGIN {
   our $var = 'Scalar' . '::' . 'Util';
 }
 use_from $var; # use Scalar::Util;

=head1 DESCRIPTION

Many people have written about Perl's problem of loading a module from a string. This module attempts to solve that problem in a safe and useful manner. Using the magic of L<Devel::Declare>, the contents of a variable are translated into a bareword C<use> statement. Since it leans on this, the safest of the loading mechanisms, it should be every bit as safe.

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Module-UseFrom>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


