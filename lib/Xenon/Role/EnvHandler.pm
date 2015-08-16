package Xenon::Role::EnvHandler; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo::Role;

with 'Xenon::Role::Log4perl', 'Xenon::Role::ConfigFromJSON';

requires 'run';

1;
__END__
