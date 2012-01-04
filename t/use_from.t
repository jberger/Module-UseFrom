use strict;
use warnings;

use Test::More;

use Module::UseFrom;

BEGIN {
  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  our $net_ftp = 'Net::FTP';
  our $scalar_util = 'Scalar::Util';
}

use_from $net_ftp;
use_from $scalar_util qw/dualvar/;

ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from variable" );

ok( defined $INC{'Scalar/Util.pm'}, "Loads Scalar::Util from variable" );
ok( __PACKAGE__->can('dualvar'), "Injection does not affect later import call" );

done_testing;

