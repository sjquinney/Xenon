package Xenon::Registry::DBD; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use DBI qw(:sql_types);

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

sub register_path {
    my ( $self, $tag, $path, $permanent, $meta_ref ) = @_;

    my %meta = $self->path_metadata( $path, $meta_ref );

    my $dbh = $self->connection;
    my $sth = $dbh->prepare_cached('SELECT tag, pathname FROM path_registry WHERE pathname = ?');

    $sth->execute($path);
    my $entry = $sth->fetchrow_hashref();

    my $sql;
    my $change_type;
    if ( defined $entry ) {
        $change_type = 'update';

        my $cur_tag = $entry->{tag};
        if ( $cur_tag ne $tag ) {
            die "Cannot register path '$path' with tag '$tag', it is owned by '$cur_tag'\n";
        }

        $sql = <<'EOT';
UPDATE path_registry SET
   pathtype  = ?,
   digest    = ?,
   digest_algorithm = ?,
   permanent = ?,
   mtime     = ?,
   mode      = ?,
   uid       = ?,
   gid       = ?
WHERE pathname = ?
EOT

    } else {
        $change_type = 'insert';

        $sql = <<'EOT';
INSERT INTO path_registry (tag, pathname, pathtype, digest, digest_algorithm, permanent, mtime, mode, uid, gid ) VALUES (?,?,?,?,?,?,?,?,?,?)
EOT

    }

    my $register = $dbh->prepare_cached($sql);

    # bind parameters separately so that some can be specified with
    # the SQL_INTEGER type for SQLite.

    my $param = 1;

    if ( $change_type eq 'insert' ) {
        $register->bind_param( 1, $tag );
        $register->bind_param( 2, $path );

        $param = 3;
    }

    for my $key ( 'pathtype', 'digest', 'digest_algorithm' ) {
        $register->bind_param( $param, $meta{$key} // q{} );
        $param++;
    }

    $register->bind_param( $param, $permanent ? 1 : 0 );
    $param++;

    for my $key ( 'mtime', 'mode', 'uid', 'gid' ) {
        $register->bind_param( $param, $meta{$key} // -1, SQL_INTEGER );
        $param++;
    }

    if ( $change_type eq 'update' ) {
        $register->bind_param( $param, $path );
    }

    try {
        $dbh->begin_work or die $dbh->errstr;

        $register->execute() or die $dbh->errstr;

        $dbh->commit() or die $dbh->errstr;
    } catch {
        die "Failed to register path '$path': $_\n";
    };

    return;
}

1;

