use strict;
use warnings;
use Test::More;

# Both come from the hub read straight from cpanfile.snapshot.
use Capture::Tiny qw(capture);
use Try::Tiny;

my ($out) = capture { print "hello\n" };
is($out, "hello\n", 'Capture::Tiny captures');

my $caught = try { die "boom\n" } catch { $_ };
is($caught, "boom\n", 'Try::Tiny catches');

done_testing;
