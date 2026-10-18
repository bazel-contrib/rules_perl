# Writes a module-definition (.def) file exporting the boot XSUBs of the given
# xsubpp outputs, as ExtUtils::Mksymlists does for MakeMaker.
#
# A Windows DLL exports nothing unless told to, and the boot XSUB is the one
# symbol DynaLoader must find in it. xsubpp declares that XSUB with
# XS_EXTERNAL, which does not carry __declspec(dllexport) on Win32; MakeMaker
# exports it through a .def file instead, and so does perl_xs. Everything else
# stays internal to the DLL.
#
# Usage: xs_def.pl --output <file.def> <file.c>...
use strict;
use warnings;
use Getopt::Long;

sub main {
    my $output;
    GetOptions("output=s" => \$output) or die "Failed to parse arguments\n";
    die "Usage: $0 --output <file.def> <file.c>...\n"
        unless defined $output && @ARGV;

    my @boot;
    for my $file (@ARGV) {
        open my $fh, '<', $file or die "Can't open '$file': $!\n";
        while (my $line = <$fh>) {
            # `XS_EXTERNAL(boot_Foo__Bar)`; older xsubpp wrote `XS(boot_Foo__Bar)`.
            push @boot, $1 if $line =~ /^XS(?:_EXTERNAL|_EUPXS)?\(\s*(boot_\w+)\s*\)/;
        }
        close $fh;
    }
    die "No boot XSUB found in: @ARGV\n" unless @boot;

    my %seen;
    open my $out, '>', $output or die "Can't write '$output': $!\n";
    print $out "EXPORTS\n";
    print $out "$_\n" for grep { !$seen{$_}++ } @boot;
    close $out or die "Can't write '$output': $!\n";
    return 0;
}

exit(main());
