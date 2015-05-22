package Xenon::Resource::URI; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Digest ();
use IO::Socket::SSL qw(SSL_VERIFY_NONE SSL_VERIFY_PEER);
use HTTP::Request ();
use HTTP::Status qw(HTTP_OK HTTP_NOT_MODIFIED);
use LWP::UserAgent 6.03 ();

use Moo;
use Types::Standard qw(Bool Maybe Str);
use Types::Path::Tiny qw(AbsPath);
use Xenon::Types qw(XenonURI);
use Try::Tiny;
use namespace::clean;

with 'Xenon::Role::Resource';

has '+source' => (
    isa    => XenonURI,
    coerce => XenonURI->coercion,
);

sub BUILDARGS {
  my ( $class, @args ) = @_;

  my %args;
  if ( scalar @args == 1 ) {
      %args = %{ $args[0] };
  } else {
      %args = @args;
  }

  # Convert explicit path to file URI
  if ( $args{source} =~ m{^/} ) {
      $args{source} = 'file://' . $args{source};
  }

  return \%args;
};

# Note that these are class methods

sub cache_dir {
    my ( $class, $new_cache_dir ) = @_;

    state $cache_dir;
    if ( defined $new_cache_dir ) {
        $cache_dir = AbsPath->coerce($new_cache_dir);
    }

    return $cache_dir;
}

sub ssl_opts {
    my ( $class, %new_settings ) = @_;

    state $verify_hostname = 1;
    if ( exists $new_settings{verify_hostname} ) {
        $verify_hostname = $new_settings{verify_hostname};
    }

    state $ca_file = $ENV{PERL_LWP_SSL_CA_FILE} || $ENV{HTTPS_CA_FILE};
    if ( exists $new_settings{ca_file} ) {
        $ca_file = $new_settings{ca_file};
    }

    state $ca_path = $ENV{PERL_LWP_SSL_CA_PATH} || $ENV{HTTPS_CA_DIR};
    if ( exists $new_settings{ca_path} ) {
        $ca_path = $new_settings{ca_path};
    }

    if (wantarray) {
        my %ssl_opts = ( verify_hostname => $verify_hostname );
        if ($verify_hostname) {
            $ssl_opts{SSL_ca_file} = $ca_file if defined $ca_file;
            $ssl_opts{SSL_ca_path} = $ca_path if defined $ca_path;

            $ssl_opts{SSL_verify_mode} = SSL_VERIFY_PEER;
        } else {
            # Needed for IO::Socket::SSL
            $ssl_opts{SSL_verify_mode} = SSL_VERIFY_NONE;
        }

        return %ssl_opts;
    }

}

sub fetch {
    my ($self) = @_;

    my $source = $self->source;

    my $ua = LWP::UserAgent->new();
    $ua->agent("Xenon/$VERSION");
    $ua->env_proxy;
    $ua->timeout(60);

    if ( $source->scheme eq 'https' ) {
        $ua->ssl_opts($self->ssl_opts);
    }

    my $req = HTTP::Request->new( GET => $source->canonical );

    my $cache_dir = $self->cache_dir();
    if ( defined $cache_dir ) {
        if ( !$cache_dir->is_dir ) {
            try {

                # Cache directory should only be accessible by user
                # and group since there might be files with 'secret'
                # content.

                $cache_dir->mkpath( { mode => oct('0770') } );
            } catch {
                $self->logger->warn("Failed to create cache directory '$cache_dir': $_");

                # Attempt to continue without caching
                $cache_dir = undef;
            };
        }
    }

    my $data;
    if ( defined $cache_dir ) {

        my $cache_file = $self->cache_file( $cache_dir, $source );

        if ( $cache_file->is_file ) {
            my $mtime = $cache_file->stat->mtime // 0;
            $self->logger->debug("Found cache file '$cache_file' with mtime '$mtime'");
            if ($mtime) {
                $req->if_modified_since($mtime);
            }
        }

        my $res = $ua->request($req);

        my $code = $res->code();
        if ( $code == HTTP_OK ) {

            # cache the content of the response with a restricted
            # umask in case there is anything 'secret' in there

            my $old_umask = umask '0007';
            $cache_file->spew($res->decoded_content);
            umask $old_umask;

        } elsif ( $code == HTTP_NOT_MODIFIED ) {
            $self->logger->debug("Using cached version of '$source'");
        } else {

            # If the request failed and there is a previously cached
            # version of the file then emit a warning and proceed with
            # the old version.

            if ( $cache_file->is_file ) {
                $self->logger->warn("Failed to fetch '$source': " . $res->status_line . ", using cached file");
            } else {
                die "Failed to fetch $source: " . $res->status_line . "\n";
            }
        }

        $data = $cache_file->slurp;
    } else { # no caching

        my $res = $ua->request($req);

        if ( $res->code() == HTTP_OK ) {
            $data = $res->decoded_content;
        } else {
            die "Failed to fetch $source: " . $res->status_line . "\n";
        }
    }

    return $data;
}

sub cache_file {
    my ( $self, $cache_dir, $source ) = @_;

    # This is a simple way of getting a unique safe file name based on
    # the URL

    my $ctx = Digest->new('SHA-1');
    $ctx->add($source->canonical);
    my $cache_file = $cache_dir->child($ctx->hexdigest);

    return $cache_file;
}

1;
