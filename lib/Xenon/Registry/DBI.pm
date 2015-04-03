package Xenon::Registry::DBI; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use DBI qw(:sql_types);
use List::MoreUtils ();
use SQL::Abstract ();

use Readonly;
Readonly my $REGISTRY_TABLE => 'path_registry';
Readonly my %INT_COLUMNS => (
    mtime   => 1,
    mode    => 1,
    uid     => 1,
    gid     => 1,
    regtime => 1,
);

use Moo;
use Types::Standard qw(Str);
use Types::Path::Tiny qw(AbsPath);
use Try::Tiny;

with 'Xenon::Role::Registry';

use namespace::clean;

has 'location' => (
    is        => 'ro',
    isa       => Str,
    required  => 1,
);

has 'user' => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_user',
);

has 'pass' => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_pass',
);

sub connection {
    my ($self) = @_;

    my @args = $self->location;
    if ( $self->has_user ) {
        push @args, $self->user;
        if ( $self->has_pass ) {
            push @args, $self->pass;
        }
    }

    my $dbh = DBI->connect_cached( @args, { AutoCommit => 1, RaiseError => 1 } )
        or die $DBI::errstr . "\n";

    my $create_table = <<"EOT";
CREATE TABLE IF NOT EXISTS $REGISTRY_TABLE (
    tag               VARCHAR(50)  NOT NULL,
    pathname          VARCHAR(200) PRIMARY KEY,
    pathtype          VARCHAR(20),
    digest            VARCHAR(200),
    digest_algorithm  VARCHAR(12),
    mtime             INTEGER,
    mode              INTEGER,
    uid               INTEGER,
    gid               INTEGER,
    permanent         BOOLEAN DEFAULT false,
    regtime           INTEGER)
EOT

    $dbh->do($create_table)
      or die 'Failed to create registry database table: ' . $dbh->errstr . "\n";

    return $dbh;
}

sub can_register_path {
    my ( $self, $tag, $supercedes, $path ) = @_;

    $supercedes //= [];
    my @tags = ( $tag, @{ $supercedes } );

    my $can_register = 1;

    my ( $is_registered, $entry ) = $self->path_is_registered($path);
    if ($is_registered) {

        my $cur_tag = $entry->{tag};
        if ( List::MoreUtils::none { $_ eq $cur_tag } @tags ) {
            $can_register = 0;
        }

    }

    return ( $can_register, $entry );
}

sub path_is_registered {
    my ( $self, $path ) = @_;

    # Using Path::Tiny to ensure path is handled consistently
    if ( !AbsPath->check($path) ) {
        $path = AbsPath->coerce($path);
    }

    my $dbh = $self->connection;
    my $sqla = SQL::Abstract->new();

    my ( $stmt, @bind ) = $sqla->select( $REGISTRY_TABLE, '*',
                                         { pathname => "$path" } );

    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);

    my $result = $sth->fetchrow_hashref;

    my $registered = defined $result ? 1 : 0;

    return ( $registered, $result );
}


sub paths_for_tag {
    my ( $self, $tag, $supercedes ) = @_;

    $supercedes //= [];
    my @tags = ( $tag, @{ $supercedes } );

    my $dbh = $self->connection;
    my $sqla = SQL::Abstract->new();

    my ( $stmt, @bind ) = $sqla->select( $REGISTRY_TABLE, ['pathname'],
                                         { tag => \@tags } );

    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);

    my $results = $sth->fetchall_arrayref([0]);

    my @paths;
    if ( defined $results ) {
        @paths = map { AbsPath->coerce( ${$_}[0] ) } @{$results};
    }

    return @paths;
}

sub get_data_for_path {
    my ( $self, $path ) = @_;

    # Using Path::Tiny to ensure path is handled consistently
    if ( !AbsPath->check($path) ) {
        $path = AbsPath->coerce($path);
    }

    my ( $is_registered, $entry ) = $self->path_is_registered($path);
    if ( !$is_registered ) {
        die "No entry in registry for path '$path'\n";
    }

    return $entry;
}

sub deregister_path {
    my ( $self, $tag, $supercedes, $path ) = @_;

    $supercedes //= [];
    my @tags = ( $tag, @{ $supercedes } );

    # Using Path::Tiny to ensure path is handled consistently
    if ( !AbsPath->check($path) ) {
        $path = AbsPath->coerce($path);
    }

    my ( $is_registered, $entry ) = $self->path_is_registered($path);

    if ($is_registered) {

        my $cur_tag = $entry->{tag};
        if ( List::MoreUtils::none { $_ eq $cur_tag } @tags ) {
            die "Cannot deregister path '$path', it is owned by '$cur_tag'\n";
        }

        my $dbh = $self->connection;
        my $sqla = SQL::Abstract->new();
        my ( $stmt, @bind ) = $sqla->delete( $REGISTRY_TABLE,
                                             { pathname => "$path",
                                               tag      => \@tags } );

        try {
            my $sth = $dbh->prepare_cached($stmt);

            $dbh->begin_work();
            $sth->execute(@bind);
            $dbh->commit();

        } catch {
            die "Failed to deregister path '$path': $_\n";
        };

    }

    return;
}

sub register_path {
    my ( $self, $tag, $supercedes, $path, $permanent, $meta_ref ) = @_;

    $supercedes //= [];
    my @tags = ( $tag, @{ $supercedes } );

    # Using Path::Tiny to ensure path is handled consistently
    if ( !AbsPath->check($path) ) {
        $path = AbsPath->coerce($path);
    }

    my %data = $self->path_metadata( $path, $meta_ref );
    $data{tag}       = $tag;
    $data{pathname}  = "$path";
    $data{permanent} = $permanent;
    $data{regtime}   = time;

    my $dbh = $self->connection;
    my $sqla = SQL::Abstract->new( bindtype => 'columns' );

    my ( $is_registered, $entry ) = $self->path_is_registered($path);

    my ($stmt, @bind);

    if ($is_registered) { # update

        my $cur_tag = $entry->{tag};
        if ( List::MoreUtils::none { $_ eq $cur_tag } @tags ) {
            die "Cannot register path, it is owned by '$cur_tag'\n";
        }

        ( $stmt, @bind ) = $sqla->update( $REGISTRY_TABLE, \%data,
                                          { pathname => "$path",
                                            tag      => \@tags } );
    } else { # insert
        ( $stmt, @bind ) = $sqla->insert( $REGISTRY_TABLE, \%data );
    }

    try {

        my $register = $dbh->prepare_cached($stmt);

        my $i = 1;
        for my $bind (@bind) {
            my( $col, $data ) = @{$bind};
            if ($INT_COLUMNS{$col}) {
                $register->bind_param( $i, $data, SQL_INTEGER );
            } else {
                $register->bind_param( $i, $data );
            }
            $i++;
        }

        $dbh->begin_work();

        $register->execute();

        $dbh->commit();
    } catch {
        die "Failed to register path '$path': $_\n";
    };

    return;
}

1;

