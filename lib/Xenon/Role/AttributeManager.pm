package Xenon::Role::AttributeManager; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;

with 'Xenon::Role::Log4perl','Xenon::Role::ConfigFromJSON';

requires 'configure';

has 'dryrun' => (
    is      => 'rw',
    isa     => Bool,
    default => sub { 0 },
);

1;
