package Xenon::Role::Log4perl; # -*- perl -*-
use strict;
use warnings;

use Log::Log4perl;
 
use Moo::Role;
use Types::Standard qw(InstanceOf);

has 'logger' => (
    is      => 'rw',
    isa     => InstanceOf['Log::Log4perl::Logger'],
    lazy    => 1,
    default => sub { return Log::Log4perl->get_logger(ref($_[0])) }
);
 
sub log {
    my $self = shift;
    my $cat = shift;
    if ($cat && $cat =~ m/^(\.|::)/) {
        return Log::Log4perl->get_logger(ref($self) . $cat);
    } elsif($cat)  {
        return Log::Log4perl->get_logger($cat);
    } else {
        return $self->logger;
    }
}
 
1;
=pod

=head1 NAME

Xenon::Role::Log4perl - Logging role for Xenon framework

=head1 VERSION

This documentation refers to Xenon::Role::Log4perl version @LCFG_VERSION@

=head1 DESCRIPTION

This is a copy of the MooseX::Log::Log4perl module without the usage
of Any::Moose and with modifications to use Types::Standard which
makes it more Moo friendly.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008-2012, Roland Lammel <lammel@cpan.org>, http://www.quikit.at

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See perlartistic.
