package Runfiles;

use strict;
use warnings;
use File::Spec;
use File::Basename qw/dirname/;
use Cwd qw/abs_path/;

=head1 NAME

Runfiles - Runfiles lookup library for Bazel-built Perl binaries and tests

=head1 SYNOPSIS

  # BUILD rule
  #
  # perl_binary(
  #     name = "my_binary",
  #     srcs = ["main.pl"],
  #     data = ["//path/to/my/data.txt"],
  #     deps = ["@rules_perl//perl/runfiles"],
  # )

  # Perl
  use Runfiles;
  my $r = Runfiles->create();
  my $path = $r->rlocation('my_workspace/path/to/my/data.txt')
      // die 'Failed to locate runfile';
  open my $fh, '<', $path or die $!;
  print do { local $/; <$fh> };

=head1 DESCRIPTION

Provides a minimal, portable API for locating Bazel runfiles.
Resolution order:

  1. C<RUNFILES_DIR> (directory-based mode, with optional C<_repo_mapping>)
  2. C<RUNFILES_MANIFEST_FILE> (manifest-based mode; C<_repo_mapping> may be
     listed in the manifest)
  3. Adjacent C<{binary}.runfiles> directory next to C<$0>

=head1 METHODS

=over 4

=item create

  my $r = Runfiles->create();

Construct a new runfiles resolver using the current environment.

=item rlocation

  my $path = $r->rlocation('workspace/path/to/file.txt');

Resolve a runfile path to an absolute filesystem path. Returns undef if the
file cannot be located.

=back

=head1 ENVIRONMENT

  RUNFILES_DIR              Directory containing runfiles tree
  RUNFILES_MANIFEST_FILE    Path to MANIFEST file mapping keys to real paths

=cut

sub create {
    my ($class) = @_;

    my $self = {
        runfiles_dir     => undef,
        manifest_file    => undef,
        manifest_map     => undef,  # lazy
        repo_mapping     => undef,  # lazy
        repo_mapping_src => undef,  # path to mapping file, if known
    };

    if (defined $ENV{RUNFILES_DIR} && length $ENV{RUNFILES_DIR}) {
        my $dir = $ENV{RUNFILES_DIR};
        $dir = File::Spec->rel2abs($dir) unless File::Spec->file_name_is_absolute($dir);
        $self->{runfiles_dir} = $dir;
        my $mapping = File::Spec->catfile($dir, '_repo_mapping');
        $self->{repo_mapping_src} = -f $mapping ? $mapping : undef;
        return bless $self, $class;
    }

    if (defined $ENV{RUNFILES_MANIFEST_FILE} && length $ENV{RUNFILES_MANIFEST_FILE}) {
        my $mf = $ENV{RUNFILES_MANIFEST_FILE};
        $mf = File::Spec->rel2abs($mf) unless File::Spec->file_name_is_absolute($mf);
        $self->{manifest_file} = $mf;
        # mapping source will be discovered from manifest
        return bless $self, $class;
    }

    # Fallback: adjacent {binary}.runfiles directory
    my $self_path = abs_path($0);
    if (defined $self_path) {
        my $base = (File::Spec->splitpath($self_path))[2];
        my $dir  = dirname($self_path);
        my $adj  = File::Spec->catdir($dir, $base . '.runfiles');
        if (-d $adj) {
            $self->{runfiles_dir} = $adj;
            my $mapping = File::Spec->catfile($adj, '_repo_mapping');
            $self->{repo_mapping_src} = -f $mapping ? $mapping : undef;
            return bless $self, $class;
        }
    }

    # No runfiles found. Still return an object; lookups will fail with undef.
    return bless $self, $class;
}

sub rlocation {
    my ($self, $rlocationpath, $source_repo) = @_;
    return undef unless defined $rlocationpath && length $rlocationpath;

    # Apply repo mapping if any
    $rlocationpath = _apply_repo_mapping($self, $rlocationpath, $source_repo);

    if (defined $self->{runfiles_dir}) {
        my $candidate = File::Spec->catfile($self->{runfiles_dir}, $rlocationpath);
        return $candidate if -e $candidate;
        return undef;
    }

    if (defined $self->{manifest_file}) {
        my $map = _load_manifest($self);
        return $map->{$rlocationpath} if exists $map->{$rlocationpath};
        return undef;
    }

    return undef;
}

# Internal helpers

sub _load_manifest {
    my ($self) = @_;
    return $self->{manifest_map} if defined $self->{manifest_map};

    my %map;
    my $mapping_src;
    my $mf = $self->{manifest_file};
    return $self->{manifest_map} = {} unless defined $mf && -f $mf;

    open my $fh, '<', $mf or die "Failed to open manifest: $mf: $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my ($key, $val) = split /\s+/, $line, 2;
        next unless defined $val;
        $map{$key} = $val;
        if ($key eq '_repo_mapping') {
            $mapping_src = $val;
        }
    }
    close $fh;

    $self->{manifest_map} = \%map;
    $self->{repo_mapping_src} //= $mapping_src if defined $mapping_src;
    return $self->{manifest_map};
}

sub _load_repo_mapping {
    my ($self) = @_;
    return $self->{repo_mapping} if defined $self->{repo_mapping};

    my %mapping;
    my $path = $self->{repo_mapping_src};

    # In directory mode, discover mapping if not already set
    if (!defined $path && defined $self->{runfiles_dir}) {
        my $candidate = File::Spec->catfile($self->{runfiles_dir}, '_repo_mapping');
        $path = $candidate if -f $candidate;
    }

    return $self->{repo_mapping} = {} unless defined $path && -f $path;

    open my $fh, '<', $path or die "Failed to open repo mapping: $path: $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @parts = split /,/, $line;
        next unless @parts >= 3;
        # Format: <source_repo>,<alias>,<target_repo>
        my $alias  = $parts[1];
        my $target = $parts[2];
        $mapping{$alias} = $target;
    }
    close $fh;

    $self->{repo_mapping} = \%mapping;
    return $self->{repo_mapping};
}

sub _apply_repo_mapping {
    my ($self, $rlocationpath, $source_repo) = @_;
    my $map = _load_repo_mapping($self);
    return $rlocationpath unless $rlocationpath =~ m{^([^/]+)/(.+)$};
    my ($repo, $rest) = ($1, $2);
    if (exists $map->{$repo}) {
        return $map->{$repo} . '/' . $rest;
    }
    return $rlocationpath;
}

1;


