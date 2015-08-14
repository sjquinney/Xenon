package Xenon::Role::Env; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo::Role;

with 'Xenon::Role::Log4perl';

requires 'run';

1;
__END__
