use strict;
use warnings;

use Test::More tests => 2;

use Module::UseFrom ':all';

can_ok( __PACKAGE__, 'use_from' );
can_ok( __PACKAGE__, 'use_if_installed' );


