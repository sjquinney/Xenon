package Xenon::Role::ContentEncoder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;

with 'Xenon::Role::ConfigFromJSON';

requires 'encode';

1;
