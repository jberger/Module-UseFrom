use strict;
use warnings;

use Test::More;

use Module::UseFrom 'use_if_installed';

BEGIN {
  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  our $var = 'Net::FTP';
}

use_if_installed $var;
ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from variable" );

done_testing;

