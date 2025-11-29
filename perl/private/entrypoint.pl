use strict;
use warnings;
use File::Spec;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use File::Copy qw/copy/;
use File::Basename qw/dirname/;
use Cwd 'abs_path';
use JSON::PP;

# Ensure enough args
die "Usage: $0 <config.json> <main.pl> -- [args...]\n" unless @ARGV >= 3;

# Extract config path and main script path
my $config_path = shift @ARGV;
my $main_path   = shift @ARGV;

# Find `--` separator
my $separator_index = 0;
$separator_index++ until $separator_index >= @ARGV || $ARGV[$separator_index] eq '--';
die "Missing -- separator after config and main script paths\n" if $separator_index == @ARGV;

# Get args after --
my @extra_args = @ARGV[ $separator_index + 1 .. $#ARGV ];
splice(@ARGV, $separator_index);  # remove args after --

# Load JSON config
open my $fh, '<', $config_path or die "Can't open config file '$config_path': $!\n";
my $json_text = do { local $/; <$fh> };
close $fh;

my $config = decode_json($json_text);
my $includes = $config->{includes} // [];
my $perlopt = $config->{perlopt} // [];

# Create RUNFILES_DIR if not set
my $runfiles = $ENV{RUNFILES_DIR};
unless (defined $runfiles) {
    my $manifest = $ENV{RUNFILES_MANIFEST_FILE}
        or die "RUNFILES_DIR is not set and RUNFILES_MANIFEST_FILE is not provided.\n";

    # Create a temporary runfiles directory
    $runfiles = tempdir(CLEANUP => 1);
    if (defined $ENV{RULES_PERL_DEBUG}) {
        warn "[DEBUG] RUNFILES_DIR created: $runfiles\n";
    }
    $ENV{RUNFILES_DIR} = $runfiles;

    # Copy entries from manifest
    open my $mfh, '<', $manifest or die "Failed to open manifest file '$manifest': $!\n";
    while (my $line = <$mfh>) {
        chomp $line;

        # skip blank lines
        next if $line =~ /^\s*$/;

        my ($rel_path, $real_path) = split ' ', $line, 2;

        # Skip any lines which don't cleanly split into key value pairs.
        next unless defined $real_path && length $real_path;

        my $dst_path = File::Spec->catfile($runfiles, $rel_path);
        make_path(dirname($dst_path));
        copy($real_path, $dst_path)
            or die "Failed to copy '$real_path' to '$dst_path': $!\n";
    }
    close $mfh;
}

# Make sure RUNFILES_DIR is absolute
unless (File::Spec->file_name_is_absolute($runfiles)) {
    $runfiles = File::Spec->rel2abs($runfiles);
    $ENV{RUNFILES_DIR} = $runfiles;
}

# Build include paths relative to RUNFILES_DIR
my @include_paths = map { File::Spec->catfile($runfiles, $_) } @$includes;

# Get current Perl interpreter
my $perl = abs_path($^X);

# Build -I include flags
my @inc_flags = map { ('-I', $_) } @include_paths;

# Build the full command array
my @cmd = ($perl, @$perlopt, @inc_flags, $main_path, @extra_args);

# Debug output if RULES_PERL_DEBUG is set
if (defined $ENV{RULES_PERL_DEBUG}) {
    warn "[DEBUG] Subprocess command: @cmd\n";
}

# Run the command in a subprocess, exit with its code
my $exit = system(@cmd);
exit($exit >> 8);
