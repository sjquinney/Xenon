package Xenon::Resource::Inline; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo;
use Types::Standard qw(ScalarRef Str);
use namespace::clean;

with 'Xenon::Role::Resource';

has '+source' => (
    isa => Str|ScalarRef[Str],
);

sub fetch {
    my ($self) = @_;

    my $source = $self->source;

    my $data;
    if ( ScalarRef->check($source) ) {
        $data = ${$source};
    } else {
        $data = $source;
    }

    return $data;
}

1;
__END__

=head1 NAME

Xenon::Resource::Inline - A simple Xenon resource for scalar data

=head1 VERSION

This documentation refers to Xenon::Resource::Inline version 1.0.0

=head1 SYNOPSIS

  use Xenon::Resource::Inline;

  my $source_data = <<'EOT';
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat.
EOT

  my $resource = Xenon::Resource::Inline->new( source => $source_data );

  my $contents = $resource->fetch();

=head1 DESCRIPTION

This class is a simple Xenon resource which can be used to fetch the
contents of a scalar string.

Xenon resources are used to provide a standard API for fetching the
source data from which the contents of files are configured. The
source might be used as the literal file contents or as a template
which is processed to generate the contents. See the documentation for
the L<Xenon::Role::FileContentManager> role for more details.

=head1 ATTRIBUTES

This class has one attribute which comes from the
L<Xenon::Role::Resource> role. Other attributes are added from the
L<Xenon::Role::Log4perl> role. See the documentation for that role for
full details.

=over

=item source

This is a required attribute which can be either a scalar string or a
reference to a scalar string. The contents of this attribute will be
returned by the C<fetch> method.

=item debug

This attribute is used to control the logging level. It can be
modified via the C<set_debug>, C<enable_debug> or C<disable_debug>
methods. This attribute is inherited from the L<Xenon::Role::Log4perl>
role.

=item logger

This attribute holds the Log4perl logger instance. This attribute is
inherited from the L<Xenon::Role::Log4perl> role.

=item logconf

This attribute holds the Log4perl logger configuration. Log4perl uses
a singleton object so this will only be used if the logger instance
has not already been initialised. This attribute is inherited from the
L<Xenon::Role::Log4perl> role.

=back

=head1 SUBROUTINES/METHODS

This class implements one method which is required by the
L<Xenon::Role::Resource> role. All other methods are inherited from
the L<Xenon::Role::Log4perl> role. See the documentation for that role
for full details.

=over

=item fetch()

This method fetches the contents of the C<source> attribute and
returns it as a scalar string.

=item enable_debug()

Turns the logging level up to DEBUG. This method is inherited from the
L<Xenon::Role::Log4perl> role.

=item disable_debug()

If the logging level had been previously raised to DEBUG then this
reverts the logging level. Alternatively if there is no previous
setting then it reduces the log level to INFO. This method is
inherited from the L<Xenon::Role::Log4perl> role.

=item set_debug($on_or_off)

Sets the value of the C<debug> attribute to be either true (1, one) or
false (0, zero). Setting the debug attribute to true will raise the
logging level to DEBUG. Setting the debug attribute to false will
restore or lower the level as described above. This method is
inherited from the L<Xenon::Role::Log4perl> role.

=back

=head1 DEPENDENCIES

This module is powered by L<Moo>. This class implements the
L<Xenon::Role::Resource::Role> role. Consequently it consumes the
L<Xenon::Role::Log4perl> role for which the L<Log::Log4perl> module
must be installed. This module uses L<Path::Tiny> via the
L<Types::Path::Tiny> module for file handling.

=head1 SEE ALSO

L<Xenon>, L<Xenon::Role::FileContentManager>

=head1 PLATFORMS

We expect this software to work on any Unix-like platform which is
supported by Perl.

=head1 BUGS AND LIMITATIONS

Please report any bugs or problems (or praise!) to the author,
feedback and patches are also always very welcome.

=head1 AUTHOR

Stephen Quinney <squinney@inf.ed.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Stephen Quinney. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL, version 2 or later.

=cut
