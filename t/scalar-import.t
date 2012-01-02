use strict;
use warnings;

use Test::More;

use Module::UseFrom;

BEGIN {
  our $var = 'Scalar::Util';
}

use_from $var qw/dualvar/;
ok( defined $INC{'Scalar/Util.pm'}, "Loads Scalar::Util from variable" );
ok( __PACKAGE__->can('dualvar'), "Injection does not affect later import call" );

done_testing;

