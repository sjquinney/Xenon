#!/usr/bin/perl
use strict;
use warnings;

use Module::Build;
my $build = Module::Build->new(
    module_name   => 'Xenon',
    dist_abstract => 'File management tools',
    dist_author   => 'Stephen Quinney <stephen@jadevine.org.uk>',
    dist_version  => '1.0.0',
    license => 'gpl',
    requires => {
        'DBI'                => 0,
        'DBD::SQLite'        => 0,
        'Digest'             => 0,
        'HTTP::Request'      => 0,
        'IO::Socket::SSL'    => 0,
        'List::MoreUtils'    => 0,
        'Log::Log4perl'      => 0,
        'LWP::UserAgent'     => '6.03',
        'MIME::Base64'       => 0,
        'Module::Find'       => 0,
        'Moo'                => '2.0',
        'namespace::clean'   => 0,
        'parent'             => 0,
        'Readonly'           => 0,
        'SQL::Abstract'      => 0,
        'Try::Tiny'          => 0,
        'Type::Tiny'         => 0,
        'Types::Path::Tiny'  => 0,
        'UNIVERSAL::require' => 0,
        'URI'                => 0,
        'URI::Escape'        => 0,
    },
    recommends => {
        'JSON'               => 0,
        'Linux::ACL'         => 0,
        'Template'           => 0,
        'YAML::XS'           => 0
    },
    build_requires => {
        'Test::More'         => '0.98',
        'Test::Exception'    => 0,
        'Test::File'         => 0,
    },
    create_makefile_pl => 'traditional',
);

$build->create_build_script;

