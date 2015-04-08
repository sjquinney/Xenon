#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use File::Path ();
use File::Spec ();
use File::Temp ();
use IO::Dir ();
use IO::File ();

use Test::More;
use Test::File;

{
    package Xenon::Test;
    use Moo;
    with 'Xenon::Role::Backup';

}

my $test1_obj = Xenon::Test->new();
isa_ok( $test1_obj, 'Xenon::Test' );
can_ok( $test1_obj, 'make_backup', 'backup_style' );

my $tmpdir = File::Temp->newdir( 'xenonXXXXXX',
                                  TMPDIR   => 1,
                                  CLEANUP  => 1 );

my $test_file = File::Spec->catfile( $tmpdir, 'example.txt' );
my $fh = IO::File->new( $test_file, 'w' )
    or die "Could not open '$test_file': $!\n";
$fh->say('hello world');
$fh->close or die "Could not close '$test_file': $!\n";

# Some files which should never be backed up

my $test_nonexist = File::Spec->catfile( $tmpdir, 'nonexistent' );
my $test_dir = File::Spec->catdir( $tmpdir, 'testdir' );
File::Path::make_path($test_dir);
my $test_link1 = File::Spec->catfile( $tmpdir, 'testlink1' );
symlink '/tmp', $test_link1;
my $test_link2 = File::Spec->catfile( $tmpdir, 'testlink2' );
symlink '/dev/null', $test_link2;

# lower-cased sorted list
my $ignore_case = sub { lc($a) cmp lc($b) };

my @dir_contents = sort $ignore_case ( '.', '..', 'example.txt', 'testdir', 'testlink1', 'testlink2' );

# 'none' style

my $test_none  = Xenon::Test->new( backup_style => 'none' );

is( $test_none->backup_style, 'none', 'backup style is \'none\'' );
is( $test_none->backup_file($test_file), undef, 'no backup file name' );

is( $test_none->make_backup($test_file), undef, 'no copy made' );

is( $test_none->make_backup($test_nonexist), undef, 'no copy of non-existent file' );
is( $test_none->make_backup($test_dir), undef, 'no copy of directory' );
is( $test_none->make_backup($test_link1), undef, 'no copy of link to directory' );
is( $test_none->make_backup($test_link2), undef, 'no copy of link to file' );

my @dir_none = sort $ignore_case IO::Dir->new($tmpdir)->read;
is_deeply( \@dir_none, \@dir_contents, 'no backup created' );

# 'tilde' style

my $test_tilde = Xenon::Test->new( backup_style => 'tilde' );
my $tilde_file = $test_file . '~';

is( $test_tilde->backup_style, 'tilde', 'backup style is \'tilde\'' );
is( $test_tilde->backup_file($test_file), $tilde_file, 'tilde backup file name' );

is( $test_tilde->make_backup($test_file), $tilde_file, 'tilde copy made' );
my $tilde_inode1 = (stat $tilde_file)[1];
is( $test_tilde->make_backup($test_file), $tilde_file, 'second copy not made' );
my $tilde_inode2 = (stat $tilde_file)[1];
ok( $tilde_inode1 == $tilde_inode2, 'second copy not made, same inode' );

is( $test_tilde->make_backup($test_nonexist), undef, 'no copy of non-existent file' );
is( $test_tilde->make_backup($test_dir), undef, 'no copy of directory' );
is( $test_tilde->make_backup($test_link1), undef, 'no copy of link to directory' );
is( $test_tilde->make_backup($test_link2), undef, 'no copy of link to file' );

my @dir_tilde = sort $ignore_case IO::Dir->new($tmpdir)->read;
@dir_contents = sort $ignore_case ( @dir_contents, 'example.txt~' );
is_deeply( \@dir_tilde, \@dir_contents, 'tilde backup exists' );

# test a change of contents

my $fh2 = IO::File->new( $test_file, 'w' )
    or die "Could not open '$test_file': $!\n";
$fh2->say('hello world again');
$fh2->close or die "Could not close '$test_file': $!\n";

is( $test_tilde->make_backup($test_file), $tilde_file, 'new copy made' );
my $tilde_inode3 = (stat $tilde_file)[1];
ok( $tilde_inode1 != $tilde_inode3, 'new copy made, different inode' );

# 'epochtime' style

my $test_epoch = Xenon::Test->new( backup_style => 'epochtime' );

is( $test_epoch->backup_style, 'epochtime', 'backup style is \'epochtime\'' );
like( $test_epoch->backup_file($test_file), qr/^\Q$test_file\E\.\d+$/, 'epoch backup file name' );

like( $test_epoch->make_backup($test_file),  qr/^\Q$test_file\E\.\d+$/, 'epoch copy made' );

is( $test_epoch->make_backup($test_nonexist), undef, 'no copy of non-existent file' );
is( $test_epoch->make_backup($test_dir), undef, 'no copy of directory' );
is( $test_epoch->make_backup($test_link1), undef, 'no copy of link to directory' );
is( $test_epoch->make_backup($test_link2), undef, 'no copy of link to file' );

my @dir_epoch = sort $ignore_case IO::Dir->new($tmpdir)->read;
my @epoch_backups = grep { m/^example\.txt\.\d+$/  } @dir_epoch;
is( scalar @epoch_backups, 1, 'epoch backup created' );

@dir_contents = sort $ignore_case ( @dir_contents, @epoch_backups );

is_deeply( \@dir_epoch, \@dir_contents, 'epoch backup exists' );

done_testing;

