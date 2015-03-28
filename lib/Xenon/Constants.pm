package Xenon::Constants; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use parent qw(Exporter);

our @EXPORT = ();
our %EXPORT_TAGS = (
    change => [qw($CHANGE_NONE $CHANGE_CREATED $CHANGE_UPDATED $CHANGE_DELETED)],
);
our @EXPORT_OK = map { @{$_} } values %EXPORT_TAGS;

use Readonly;

Readonly our $CHANGE_NONE    => 0;
Readonly our $CHANGE_CREATED => 1;
Readonly our $CHANGE_UPDATED => 2;
Readonly our $CHANGE_DELETED => 4;

1;

