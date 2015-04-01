#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More;

use_ok('Xenon::TypeUtils');
use_ok('Xenon::Types');

use_ok('Xenon::ContentDecoder::Base64');

use_ok('Xenon::Resource::File');
use_ok('Xenon::Resource::Inline');
use_ok('Xenon::Resource::URI');

use_ok('Xenon::File::Directory');
use_ok('Xenon::File::Link');
use_ok('Xenon::File::Static');
use_ok('Xenon::File::TT');

use_ok('Xenon::Registry::DBD');

done_testing;