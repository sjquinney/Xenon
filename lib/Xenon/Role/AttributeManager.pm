package Xenon::Role::AttributeManager; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Types::Standard qw(Bool);

use Moo::Role;

with 'Xenon::Role::Log4perl','Xenon::Role::ConfigFromJSON';

requires 'configure';

has 'dryrun' => (
    is      => 'rw',
    isa     => Bool,
    default => sub { 0 },
);

1;
__END__

=head1 NAME

Xenon::Role::AttributeManager - A Moo role which defines a content decoder

=head1 VERSION

This documentation refers to Xenon::Role::AttributeManager version 1.0.0

=head1 SYNOPSIS

  {
    package Xenon::Attributes::Test;

    use Types::Standard qw(Str);
    use Moo;
    with 'Xenon::Role::AttributeManager';

    has 'mode' => (
        is      => 'ro',
        isa     => Str,
        default => '0700'
    );

    sub configure {
        my ( $self, $path ) = @_;

        chmod oct($self->mode), $path
            or die "Could not chmod $path: $!\n";

        return;
    }
  }

  my $attr = Xenon::Attributes::Test->new( mode => '0600' );
  $attr->configure();

=head1 DESCRIPTION

This is a Moo role which defines a standard API for a class which can
be used to configure arbitrary file attributes. Attributes can be
anything associated with a file or directory (e.g. ACLs, capabilities,
xattr, SELinux contexts). Any class which implements this role is
guaranteed to have a C<configure> method. Although not required,
typically those classes will appear in the L<Xenon::Attributes>
namespace.

=head1 ATTRIBUTES

This role adds one attribute to a consuming class. Other attributes
are added from the L<Xenon::Role::Log4perl> and
L<Xenon::Role::ConfigFromJSON> roles. See the documentation for those
roles for full details.

=over

=item dryrun

This is a boolean attribute which indicates whether or not to actually
apply any necessary changes. The default value is C<false>. When the
setting is C<true> the C<configure> method should log what would have
been done with a C<Dry-run:> prefix.

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

This role requires that a consuming class implements a C<configure>
method. All other methods are inherited from other roles.

=over

=item configure($path)

This method MUST be implemented by any class which consumes this
role. It takes a path to a file or directory for which the attributes
need to be configured. Attributes can be anything associated with the
file (e.g. ACLs, capabilities, xattr, SELinux contexts). This method
should throw an exception if the path does not exist.

=item new_from_json( $json, @overrides )

This role imports the L<Xenon::Role::ConfigFromJSON> role which adds a
C<new_from_json> method. This can be used to create a new instance
with the option to specify attributes as a JSON file or string. See
the documentation for that role for more details.

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

This module is powered by L<Moo>. It requires the
L<Xenon::Role::ConfigFromJSON> role, to use that role the L<JSON>
module must be available. It also requires the
L<Xenon::Role::Log4perl> role for which the L<Log::Log4perl> module
must be installed.

=head1 SEE ALSO

L<Xenon>

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
