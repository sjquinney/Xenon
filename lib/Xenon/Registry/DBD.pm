package Xenon::Registry::DBD; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use DBI qw(:sql_types);
use SQL::Abstract ();

my %INT_COLUMNS = (
    'mtime' => 1,
    'mode'  => 1,
    'uid'   => 1,
    'gid'   => 1,
);

use Moo;
use Types::Standard qw(Str);
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

    my $create_table = <<'EOT';
CREATE TABLE IF NOT EXISTS path_registry (
    tag               VARCHAR(50)  NOT NULL,
    pathname          VARCHAR(200) PRIMARY KEY,
    pathtype          VARCHAR(20),
    digest            VARCHAR(200),
    digest_algorithm  VARCHAR(12),
    mtime             INTEGER,
    mode              INTEGER,
    uid               INTEGER,
    gid               INTEGER,
    permanent         BOOLEAN DEFAULT false)
EOT

$dbh->do($create_table)
or die 'Failed to create registry database table: ' . $dbh->errstr . "\n";

    return $dbh;
}

sub path_is_registered {
    my ( $self, $path ) = @_;

    my $dbh = $self->connection;
    my $sth = $dbh->prepare_cached('SELECT * FROM path_registry WHERE pathname = ?');

    $sth->execute($path);
    my $result = $sth->fetchrow_hashref;

    my $registered = defined $result ? 1 : 0;

    return ( $registered, $result );
}


sub paths_for_tag {
    my ( $self, $tag ) = @_;

    my $dbh = $self->connection;
    my $sth = $dbh->prepare_cached('SELECT pathname FROM path_registry WHERE tag = ?');

    $sth->execute($tag);

    my $results = $sth->fetchall_arrayref([0]);

    my @paths;
    if ( defined $results ) {
        @paths = map { @{$_} } @{$results};
    }

    return @paths;
}

sub deregister_path {
    my ( $self, $tag, $path ) = @_;

    my ( $is_registered, $entry ) = $self->path_is_registered($path);

    if ($is_registered) {

        my $cur_tag = $entry->{tag};
        if ( $cur_tag ne $tag ) {
            die "Cannot deregister path '$path' with tag '$tag', it is owned by '$cur_tag'\n";
        }

        my $dbh = $self->connection;
        my $sqla = SQL::Abstract->new();
        my ( $stmt, @bind ) = $sqla->delete( 'path_registry',
                                             { pathname => $path,
                                               tag      => $tag } );

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
    my ( $self, $tag, $path, $permanent, $meta_ref ) = @_;

    my %data = $self->path_metadata( $path, $meta_ref );
    $data{tag}       = $tag;
    $data{pathname}  = $path;
    $data{permanent} = $permanent;

    my $dbh = $self->connection;
    my $sqla = SQL::Abstract->new( bindtype => 'columns' );

    my ( $is_registered, $entry ) = $self->path_is_registered($path);

    my($stmt, @bind);

    if ($is_registered) { # update

        my $cur_tag = $entry->{tag};
        if ( $cur_tag ne $tag ) {
            die "Cannot register path '$path' with tag '$tag', it is owned by '$cur_tag'\n";
        }

        ( $stmt, @bind ) = $sqla->update( 'path_registry', \%data,
                                          { pathname => $path } );
    } else { # insert
        ( $stmt, @bind ) = $sqla->insert( 'path_registry', \%data );
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

