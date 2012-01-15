use strict;
use warnings;

use Test::More;

use ExtUtils::Installed;

use Module::UseFrom 'use_if_available';

my %non_core;
my $rewritten;

#declare these outside to inspect later
our ($core, $bad, $version_bad);

BEGIN {
  $Module::UseFrom::verbose = \$rewritten;

  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  warn "Pod::Parser already loaded\n" if defined $INC{'Pod/Parser.pm'};
  $core = 'Net::FTP';
  our $version_ok = 'Pod::Parser';
  $version_bad = 'Net::POP3';
  our $version_ok_import = 'Carp';
  our $version_bad_import = 'Scalar::Util';
  $bad = 'Something::That::Isnt::Installed';
  our $non_core = '';

  my $inst = ExtUtils::Installed->new();
  foreach my $module ($inst->modules()) {
    next if $module =~ /Acme/;
    next if $module eq 'Perl';

    my $filename = $module;
    $filename =~ s'::'/'g;
    $filename .= '.pm';
    unless ($INC{$filename}) {
      $non_core = $non_core{module} = $module;
      $non_core{filename} = $filename;
      last;
    }
  }
}

use_if_available $core;
use_if_available $bad;
use_if_available $non_core;

use_if_available $version_ok 0.01;
use_if_available $version_bad 999;

use_if_available $version_ok_import 0.01 qw/croak/;
use_if_available $version_bad_import 999 qw/dualvar/;

ok( 1, q/Doesn't die on bad modules/ );
unlike( $rewritten, qr/use\s+Something::That::Isnt::Installed/, "no use statement of not-installed module" );

ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from scalar" );
like( $rewritten, qr/Net::FTP/, "Net::FTP statement in variable" );

ok( defined $INC{'Pod/Parser.pm'}, "Loads Pod::Parser with version" );
like( $rewritten, qr/Pod::Parser/, "Pod::Parser (with version) statement in variable" );

unlike( $rewritten, qr/use\s+Net::POP3/, "Net::POP3 not in statement with version 999" );

ok( __PACKAGE__->can('croak'), "Imports croak (with version)" );
ok( ! __PACKAGE__->can('dualvar'), "Does not import dualvar (bad version)" );

ok( $core > 0, "loaded core module returns numerical value" );
is( $core, 'Net::FTP', "dualvar does not wreck string value" );

ok( $bad == 0, "non-loaded not-installed module is numerically zero" );
ok( $version_bad == 0, "non-loaded bad-version module is numerically zero" );

SKIP: {
  skip "No non-core module installed but not loaded", 1 unless $non_core{module};
  ok( defined $INC{$non_core{filename}}, "Loads non-core module ($non_core{module})" );
}

done_testing;

