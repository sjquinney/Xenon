package Xenon::Role::Log4perl; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Readonly;
Readonly my $DEFAULT_CONFIG_FILE => '/etc/xenon/log.conf';

use Log::Log4perl qw(:easy);
 
use Moo::Role;
use Types::Path::Tiny qw(AbsPath);
use Types::Standard qw(Bool InstanceOf ScalarRef Str);

has 'debug' => (
    is      => 'rw',
    isa     => Bool,
    default => sub { 0 },
    writer  => 'set_debug',
);

has 'logger' => (
    is      => 'ro',
    isa     => InstanceOf['Log::Log4perl::Logger'],
    lazy    => 1,
    builder => '_build_logger',
);

has 'logconf' => (
    is      => 'ro',
    isa     => ScalarRef[Str],
    coerce  => sub {
        my $conf = \ q{};
        if ( ScalarRef->check($_[0]) ) {
            $conf = $_[0];
        } elsif ( defined $_[0] ) {

            my $file = AbsPath->coerce($_[0]);
            if ( !AbsPath->check($file) || !$file->is_file ) {
                die "Failed to load logging configuration from '$file'\n";
            }
            $conf = \ $file->slurp;
        }
        return $conf;
    },
    builder => '_build_logconf',
);

sub _build_logconf {
    my ($self) = @_;

    my $conf;
    if ( -f $DEFAULT_CONFIG_FILE ) {
        $conf = $DEFAULT_CONFIG_FILE;
    } else {
        $conf = \<<'EOT'
log4perl.logger.Xenon              = INFO, ScreenApp
log4perl.appender.ScreenApp        = Log::Log4perl::Appender::Screen
log4perl.appender.ScreenApp.stderr = 1
log4perl.appender.ScreenApp.layout = PatternLayout
log4perl.appender.ScreenApp.layout.ConversionPattern = %d: [%p] %m%n
EOT
    }
}

sub _build_logger {
    my ($self) = @_;

    if ( !Log::Log4perl->initialized() ) {

        my $logconf = $self->logconf;
        if ( $logconf && ${$logconf} =~ m/\S/ ) {
            Log::Log4perl->init_once($logconf);
        } else {
            Log::Log4perl->easy_init($INFO);
        }

    }

    my $class_name = ref $self;
    my $logger = Log::Log4perl->get_logger($class_name);

    # Raise the level when necessary
    if ( $self->debug && !$logger->is_debug ) {
        $logger->level($DEBUG);
    }

    return $logger;
}

# Tried doing this with a trigger and it did not play nicely with
# setting the debug level via the constructor. We only care about
# *changes* to the level at some later time so using "after" is
# sufficient.

after 'set_debug' => sub {
    my ( $self, $value ) = @_;

    my $logger = $self->logger;

    # When raising the level to DEBUG the previous level is stashed so
    # that it is possible to return to the previous setting at some
    # later time.

    state $previous_level;

    if ($value) {

        # Only raise when the level is lower than debug
        if ( !$logger->is_debug ) {
            $previous_level = $logger->level();
            $logger->level($DEBUG);
        }

    } else {

        # Only lower when the level is at debug or higher
        if ( $logger->is_debug ) {

            if ( defined $previous_level ) {
                $logger->level($previous_level);
            } else {
                $logger->level($INFO);
            }

        }

    }

    return;
};

# Convenience methods

sub  enable_debug { $_->[0]->set_debug(1) }
sub disable_debug { $_->[0]->set_debug(0) }

1;
=pod

=head1 NAME

Xenon::Role::Log4perl - Logging role for Xenon framework

=head1 VERSION

This documentation refers to Xenon::Role::Log4perl version @LCFG_VERSION@

=head1 DESCRIPTION

=head1 AUTHOR

Stephen Quinney <squinney@inf.ed.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 University of Edinburgh. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL, version 2 or later.



