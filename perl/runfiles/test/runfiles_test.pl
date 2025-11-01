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

# Regression test: create() should work when called on an instance
my $r1 = Runfiles->create();
ok(defined $r1, 'create() works as class method');

my $r2 = $r1->create();
ok(defined $r2, 'create() works when called on an instance');
ok(ref($r2) eq 'Runfiles', 'instance method returns correct class');

done_testing();
