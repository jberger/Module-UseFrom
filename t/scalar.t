use strict;
use warnings;

use Test::More;

use Module::UseFrom;

BEGIN {
  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  our $var = 'Net::FTP';
}

use_from $var;
ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from variable" );

done_testing;

