#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More;

BEGIN { use_ok( 'Xenon::Encoding::Base64' ); }

my $decoder = Xenon::Encoding::Base64->new();

isa_ok( $decoder, 'Xenon::Encoding::Base64' );

can_ok( $decoder, 'decode' );

is( $decoder->decode('aGVsbG8gd29ybGQ='), 'hello world', 'decode test' );

# This is the slightly bizarre LCFG-style base64 encoding, note that
# those are *literal* \n strings and NOT newlines.

my $lcfg_in = q(IyBHZW5lcmF0ZWQgZmlsZSBkbyBub3QgZWRpdAo=\n\nL3Zhci9sb2cvY3Vwcy8qX2xvZyB7Cg==\ncm90YXRlIDI2Cg==\nY29tcHJlc3MK\nbWlzc2luZ29rCg==\nbm90aWZlbXB0eQo=\nc2hhcmVkc2NyaXB0cwo=\nfQo=\n);

my $lcfg_out = <<'EOT';
# Generated file do not edit

/var/log/cups/*_log {
rotate 26
compress
missingok
notifempty
sharedscripts
}
EOT

is( $decoder->decode($lcfg_in), $lcfg_out, 'LCFG-style decode test' );

# Same configuration file, encoded in a more normal style.

my $normal = <<'EOT';
IyBHZW5lcmF0ZWQgZmlsZSBkbyBub3QgZWRpdAoKL3Zhci9sb2cvY3Vwcy8qX2xvZyB7CnJvdGF0
ZSAyNgpjb21wcmVzcwptaXNzaW5nb2sKbm90aWZlbXB0eQpzaGFyZWRzY3JpcHRzCn0K
EOT

# Test to ensure encoding some Perl works correctly

is( $decoder->decode($normal), $lcfg_out, 'Normal-style decode test' );

my $code_in = 'IyEvdXNyL2Jpbi9wZXJsCgojICBraWxsIGpvYnMgdGhhdCBhcmUgcnVubmluZyB0b28gbG9uZy4K\nCgppZiAob3BlbiBPTEQsICIvdmFyL3RtcC9sYXN0LWhhZG9vcC1qb2JzLnR4dCIpIHsKCiAgbXkg\nJW9sZDsKCiAgIyBnZXQgbGlzdCBvZiBqb2JzIHRoYXQgd2VyZSBydW5uaW5nIGxhc3QgdGltZSB3\nZSBjaGVja2VkCiAgd2hpbGUoIWVvZihPTEQpKXsKICAgICRqb2IgPSA8T0xEPjsKICAgICgkam9i\nSUQpID0gc3BsaXQoL1xzKy8sJGpvYik7CiAgICAjICBwcmludCAiJGpvYklEXG4iOwogICAgJG9s\nZHskam9iSUR9PTE7CiAgfQoKICBjbG9zZSBPTEQ7CgogIG9wZW4gSk9CUywgICIvb3B0L2hhZG9v\ncC9oYWRvb3AtMC4yMC4yL2Jpbi9oYWRvb3Agam9iIC1saXN0IHwiIG9yIGRpZSAiY291bGQgbm90\nIG9wZW4gcGlwZSAtLWNoZWNrIHRoYXQgaGFkb29wIGlzIGluIHBhdGgiOwogIG9wZW4gT0xELCAi\nPi92YXIvdG1wL2xhc3QtaGFkb29wLWpvYnMudHh0IiBvciBkaWUgImNhbm5vdCBjcmVhdGUgbGlz\ndCBvZiBydW5uaW5nIGpvYnMiOwoKICAjd2hpbGUoIWVvZihKT0JTKSl7CiAgIyAgJGpvYiA9IDxK\nT0JTPjsKICB3aGlsZSgkam9iID0gPEpPQlM+KSB7CiAgICBpZiAoJGpvYiA9fiAvXmpvYl8uKi8p\nIHsKICAgICAgKCRqb2JJRCkgPSBzcGxpdCgvXHMrLywkam9iKTsKICAgICAgIyAgICBwcmludCAi\nSm9iIElEOiAkam9iSURcbiI7CiAgICAgIGlmICgkb2xkeyRqb2JJRH0pIHsKCXN5c3RlbSAiL29w\ndC9oYWRvb3AvaGFkb29wLTAuMjAuMi9iaW4vaGFkb29wIGpvYiAta2lsbCAkam9iSUQiOwoJcHJp\nbnQgIktpbGxpbmcgam9iICRqb2JJRFxuIjsKICAgICAgfSBlbHNlIHsKCXByaW50IE9MRCAiJGpv\nYklEXG4iOwogICAgICB9CiAgICB9CiAgfQogIGNsb3NlIE9MRDsKICBjbG9zZSBKT0JTOwoKfSBl\nbHNlIHsKCiAgIyBJZiB3ZSBjYW4ndCBvcGVuIHRoZSBqb2JzIGZpbGUgZnJvbSBsYXN0IHRpbWUs\nCiAgIyBtYWtlIGEgbmV3IGVtcHR5IGZpbGUgdGhlbiBleGl0LgoKICAjIHN5c3RlbSBnaXZlcyBh\nIDAgZXhpdCBzdGF0dXMgb24gc3VjY2VzcwogIGlmIChzeXN0ZW0gIi9iaW4vdG91Y2ggL3Zhci90\nbXAvbGFzdC1oYWRvb3Atam9icy50eHQiKSB7CiAgICBkaWUgImNhbid0IGNyZWF0ZSAvdmFyL3Rt\ncC9sYXN0LWhhZG9vcC1qb2JzLnR4dCI7CiAgfQoKfQo=';

my $code_out = <<'EOT';
#!/usr/bin/perl

#  kill jobs that are running too long.


if (open OLD, "/var/tmp/last-hadoop-jobs.txt") {

  my %old;

  # get list of jobs that were running last time we checked
  while(!eof(OLD)){
    $job = <OLD>;
    ($jobID) = split(/\s+/,$job);
    #  print "$jobID\n";
    $old{$jobID}=1;
  }

  close OLD;

  open JOBS,  "/opt/hadoop/hadoop-0.20.2/bin/hadoop job -list |" or die "could not open pipe --check that hadoop is in path";
  open OLD, ">/var/tmp/last-hadoop-jobs.txt" or die "cannot create list of running jobs";

  #while(!eof(JOBS)){
  #  $job = <JOBS>;
  while($job = <JOBS>) {
    if ($job =~ /^job_.*/) {
      ($jobID) = split(/\s+/,$job);
      #    print "Job ID: $jobID\n";
      if ($old{$jobID}) {
	system "/opt/hadoop/hadoop-0.20.2/bin/hadoop job -kill $jobID";
	print "Killing job $jobID\n";
      } else {
	print OLD "$jobID\n";
      }
    }
  }
  close OLD;
  close JOBS;

} else {

  # If we can't open the jobs file from last time,
  # make a new empty file then exit.

  # system gives a 0 exit status on success
  if (system "/bin/touch /var/tmp/last-hadoop-jobs.txt") {
    die "can't create /var/tmp/last-hadoop-jobs.txt";
  }

}
EOT

is( $decoder->decode($code_in), $code_out, 'Perl code test' );

# Test a class which implements Encoder and Decoder

{
    package Xenon::Encoding::Rot13;

    use Moo;
    with 'Xenon::Role::ContentEncoder', 'Xenon::Role::ContentDecoder';

    sub encode {
        my ( $self, $in ) = @_;
        my $out = $in;
        $out =~ tr/A-Za-z/N-ZA-Mn-za-m/;

        return $out;
    }
    sub decode {
        my ( $self, $in ) = @_;
        return $self->encode($in);
    }

}

my $rot13 = Xenon::Encoding::Rot13->new();

isa_ok( $rot13, 'Xenon::Encoding::Rot13' );

can_ok( $rot13, 'decode', 'encode' );

is( $rot13->encode('hello world'), 'uryyb jbeyq', 'rot13 encode test' );
is( $rot13->decode('uryyb jbeyq'), 'hello world', 'rot13 decode test' );

done_testing;
