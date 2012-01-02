use strict;
use warnings;

use Test::More;

use ExtUtils::Installed;

use Module::UseFrom;

my %non_core;
BEGIN {
  $Module::UseFrom::check_installed = 1;

  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  our @var = qw'Net::FTP Something::That::Isnt::Installed';

  my $inst = ExtUtils::Installed->new();
  my @installed = $inst->modules();

  foreach my $module (@installed) {
    next if $module =~ /Acme/;

    my $filename = $module;
    $filename =~ s'::'/'g;
    $filename .= '.pm';
    unless ($INC{$filename}) {
      $non_core{module} = $module;
      $non_core{filename} = $filename;
      push @var, $module;
      last;
    }
  }
}

use_from @var;
ok( 1, q/Doesn't die on Module not found in @INC/ );
ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from array" );

SKIP: {
  skip "No non-core module installed but not loaded", 1 unless $non_core{module};
  ok( defined $INC{$non_core{filename}}, "Loads non-core module ($non_core{module})" );
}

done_testing;

