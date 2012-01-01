use strict;
use warnings;

use Test::More;

use Module::UseFrom;

BEGIN {
  warn "Pod::Parser already loaded\n" if defined $INC{'Pod/Parser.pm'};
  warn "Net::FTP already loaded\n" if defined $INC{'Net/FTP.pm'};
  our @var = qw'Pod::Parser Net::FTP';
}

use_from @var;
ok( defined $INC{'Pod/Parser.pm'}, "Loads Pod::Parser from array" );
ok( defined $INC{'Net/FTP.pm'}, "Loads Net::FTP from array" );


done_testing;

