use strict;
use warnings;

use Test::More tests => 5;
use File::Spec;

# Ensure the module is importable via nominal means
use Runfiles;

subtest 'data file access via runfiles' => sub {
    plan tests => 2;

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
};

subtest 'Runfiles->create() as class method' => sub {
    plan tests => 1;

    my $r = Runfiles->create();
    ok(defined $r, 'create() returns a defined object');
};

subtest 'create() called on instance (regression test)' => sub {
    plan tests => 2;

    my $r1 = Runfiles->create();
    my $r2 = $r1->create();

    ok(defined $r2, 'create() works when called on an instance');
    ok(ref($r2) eq 'Runfiles', 'instance method returns correct class');
};

subtest 'rlocation returns undef for non-existent file' => sub {
    plan tests => 1;

    my $r = Runfiles->create();
    my $path = $r->rlocation('non/existent/file.txt');

    ok(!defined $path, 'rlocation returns undef for non-existent file');
};

subtest 'rlocation returns undef for empty path' => sub {
    plan tests => 1;

    my $r = Runfiles->create();
    my $path = $r->rlocation('');

    ok(!defined $path, 'rlocation returns undef for empty path');
};
