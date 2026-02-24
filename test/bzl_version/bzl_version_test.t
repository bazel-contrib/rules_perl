# A suite of tests ensuring version strings are all in sync.

use strict;
use warnings;

use Test::More tests => 1;
use File::Spec;

use Runfiles;

sub rlocation {
    my ($runfiles, $rlocationpath) = @_;
    my $runfile = $runfiles->rlocation($rlocationpath);
    if (!defined $runfile || !length $runfile) {
        die "Failed to find runfile: $rlocationpath";
    }
    if (!-e $runfile) {
        die "Runfile does not exist: ($rlocationpath) $runfile";
    }
    return $runfile;
}

subtest 'version.bzl and MODULE.bazel versions are synced' => sub {
    plan tests => 1;

    my $runfiles = Runfiles->create();
    if (!defined $runfiles) {
        die "Failed to locate runfiles.";
    }

    my $version_bzl_path = rlocation($runfiles, $ENV{VERSION_BZL});
    open my $vbfh, '<:utf8', $version_bzl_path or die "open $version_bzl_path: $!";
    my $version_bzl_content = do { local $/; <$vbfh> };
    close $vbfh;

    my ($bzl_version) = $version_bzl_content =~ /VERSION\s*=\s*"([\w.]+)"/m;
    if (!defined $bzl_version) {
        die "Failed to parse version from $version_bzl_path";
    }

    my $module_bazel_path = rlocation($runfiles, $ENV{MODULE_BAZEL});
    open my $mbfh, '<:utf8', $module_bazel_path or die "open $module_bazel_path: $!";
    my $module_bazel_content = do { local $/; <$mbfh> };
    close $mbfh;

    my ($module_version) = $module_bazel_content =~ /module\s*\(\s*name\s*=\s*"rules_perl",\s*version\s*=\s*"([\w.]+)",\s*\)/s;
    if (!defined $module_version) {
        die "Failed to parse version from $module_bazel_path";
    }

    is($bzl_version, $module_version, "version.bzl ($bzl_version) == MODULE.bazel ($module_version)");
};
