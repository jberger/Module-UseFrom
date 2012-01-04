use strict;
use warnings;

use Test::More tests => 2;

use Module::UseFrom 'use_if_installed';

can_ok( __PACKAGE__, 'use_if_installed' );
ok( ! __PACKAGE__->can('use_from'), "imported with option doesn't load default" );


