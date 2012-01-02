use strict;
use warnings;

use Test::More;

my $verbose;

use Module::UseFrom;

BEGIN {
  $Module::UseFrom::verbose = \$verbose;

  our %modules = (
    'Net::FTP' => { 
      check_installed => 1,
      version => 999.999,
    },
    'Scalar::Util' => {
      'import' => [ qw/dualvar/ ],
    },
    'Carp' => {
      version => 0.01,
      'import' => [ qw/croak/ ]
    },
  );
}
  
use_from %modules;

ok( ! defined $INC{'Net/FTP.pm'}, "Module not loaded if check_installed and version incorrect" );

ok( defined $INC{'Scalar/Util.pm'}, "Module loaded (Scalar::Util)" );
ok( __PACKAGE__->can('dualvar'), "Import succeeds (dualvar)" );

ok( defined $INC{'Carp.pm'}, "Module loaded (Carp)" );
like( $verbose, qr'use Carp 0.01', "Carp loaded with specific version" );
ok( __PACKAGE__->can('croak'), "Import succeeds (croak)" );

done_testing;

