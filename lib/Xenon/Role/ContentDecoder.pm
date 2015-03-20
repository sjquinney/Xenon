package Xenon::Role::ContentDecoder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;

with 'Xenon::Role::ConfigFromJSON';

requires 'decode';

1;
