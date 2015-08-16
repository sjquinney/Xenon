package Xenon::Role::EnvManager; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo::Role;
use Xenon::Types qw(XenonEnvHandlerList);

with 'Xenon::Role::Log4perl';

has 'env' => (
    is      => 'ro',
    isa     => XenonEnvHandlerList,
    coerce  => XenonEnvHandlerList->coercion,
    default => sub { [] },
);

sub initialise_environment {
    my ($self) = @_;

    for my $handler ( @{ $self->env } ) {
        $self->logger->debug("Running $handler env handler");
        $handler->run();
    }

    return;
}

1;
__END__
