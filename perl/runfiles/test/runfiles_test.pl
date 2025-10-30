#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

# Ensure the module is importable via nominal means
use Runfiles;
use File::Spec;

my $path = $ENV{DATA_FILE} // $ENV{DATA_PATH};
ok(defined $path && length $path, 'DATA_FILE is set');

if (!File::Spec->file_name_is_absolute($path)) {
    my $r = Runfiles->create();
    my $resolved = $r->rlocation($path);
    $path = $resolved if defined $resolved;
}

open my $fh, '<', $path or die "open $path: $!\n";
my $content = do { local $/; <$fh> };
close $fh;

is($content, "Hello, Perl\n", 'data file content matches');

done_testing();


