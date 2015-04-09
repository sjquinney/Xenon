package Xenon::Role::Resource; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo::Role;

with 'Xenon::Role::Log4perl';

requires 'fetch';

has 'source' => (
    is       => 'ro',
    required => 1,
);

1;
__END__

=head1 NAME

Xenon::Role::Resource - A Moo role which defines a Xenon resource

=head1 VERSION

This documentation refers to Xenon::Role::Resource version 1.0.0

=head1 SYNOPSIS

  {
    package Xenon::Resource::Test;

    use IO::File ();

    use Moo;
    with 'Xenon::Role::Resource';

    sub fetch {
        my ($self) = @_;

        my $fh = IO::File->new( $self->source, 'r' )
            or die "Cannot open source file: $!\n";

        my $data = do { $/ = undef; <$fh> };

        return $data;
    }
  }

  my $res = Xenon::Resource::Test->new( source => "/tmp/example.tt" );
  my $tmpl = $res->fetch();

=head1 DESCRIPTION

This is a Moo role which defines a standard API for a class which can
be used to fetch data from a location. This location could be
anything, for example a local file or a remote resource accessible via
http.

Xenon resources are used to provide the source data from which the
contents of files are configured. The source might be used as the
literal file contents or as a template which is processed to generate
the contents. See the documentation for the
L<Xenon::Role::FileContentManager> role for more details.

=head1 ATTRIBUTES

This role adds one attribute to a consuming class. Other attributes
are added from the L<Xenon::Role::Log4perl> role. See the
documentation for that role for full details.

=over

=item source

When creating a new instance of a class which implements this role a
value MUST be specified for this attribute. It can be any string,
implementing classes may wish to modify the type to be more
restrictive.

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

This role requires that a consuming class implements a C<fetch>
method. All other methods are inherited from other roles.

=over

=item fetch()

This method MUST be implemented by any class which consumes this
role. It fetches the contents of data source stored in the location
specified in the C<source> attribute and returns it as a string. This
method should die if it is not possible to fetch the resource.

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

This module is powered by L<Moo>. It also requires the
L<Xenon::Role::Log4perl> role for which the L<Log::Log4perl> module
must be installed.

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
