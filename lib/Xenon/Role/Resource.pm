package Xenon::Role::Resource; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;

with 'Xenon::Role::Log4perl';

requires 'fetch';

has 'source' => (
    is       => 'ro',
    required => 1,
);

1;
