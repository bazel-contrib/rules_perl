# Translates a Perl XS file to C, like the `xsubpp` script shipped with perl.
#
# ExtUtils::ParseXS chdirs into the directory of the `.xs` file before reading
# typemaps, so they are made absolute here. That lets Bazel pass every path as
# an execroot relative path, which keeps the action compatible with path
# mapping.
#
# Usage: xsubpp.pl [--typemap <file>]... --output <file.c> <file.xs>
use strict;
use warnings;
use File::Spec;

# That chdir also breaks a relative @INC. A relocatable perl invoked by a
# relative path, as Bazel invokes it, keeps $^X and so @INC relative when it
# cannot read /proc/self/exe (the static Linux build has no procselfexe), and
# the modules ParseXS loads lazily, such as ExtUtils::Typemaps, are then not
# found. So @INC is made absolute first.
BEGIN { @INC = map { ref($_) ? $_ : File::Spec->rel2abs($_) } @INC }

use ExtUtils::ParseXS;
use Getopt::Long;

sub main {
    my @typemaps;
    my $output;
    GetOptions(
        "typemap=s" => \@typemaps,
        "output=s"  => \$output,
    ) or die "Failed to parse arguments\n";
    die "Usage: $0 [--typemap <file>]... --output <file.c> <file.xs>\n"
        unless defined $output && @ARGV == 1;

    my $pxs = ExtUtils::ParseXS->new;
    $pxs->process_file(
        filename => $ARGV[0],
        output   => $output,
        typemap  => [ map { File::Spec->rel2abs($_) } @typemaps ],
    );
    return $pxs->report_error_count() ? 1 : 0;
}

exit(main());
