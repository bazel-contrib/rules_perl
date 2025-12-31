use strict;
use warnings;
use Carton::CLI;
use Cwd 'abs_path', 'getcwd';
use File::Slurp;
use File::Spec;
use File::Temp qw(tempdir);
use HTTP::Tiny;
use JSON::PP;
use Time::HiRes qw(sleep);

sub parse_args {
    my %opts;
    my $cwd = getcwd();

    for my $var (qw(
        PERL_CPAN_COMPILER_CPANFILE
        PERL_CPAN_COMPILER_LOCKFILE
    )) {
        die "Environment variable $var is not set\n" unless exists $ENV{$var};
    }

    for my $key (['cpanfile', 'PERL_CPAN_COMPILER_CPANFILE'],
                 ['lockfile', 'PERL_CPAN_COMPILER_LOCKFILE']) {

        my ($name, $env) = @$key;
        my $path = $ENV{$env};
        $path = File::Spec->rel2abs($path, $cwd);
        $opts{$name} = $path;
    }

    $opts{incremental} = 0;
    for my $arg (@ARGV) {
        if ($arg eq '--incremental') {
            $opts{incremental} = 1;
        }
    }

    return %opts;
}

sub deserialize_cpanfile_snapshot {
    my ($content) = @_;
    my %results;
    my $current = "";
    my $container_name = "";

    for my $line (split /\n/, $content) {
        my $text = $line;
        $text =~ s/^\s+|\s+$//g;
        next if !$text || $text =~ /^#/;

        if ($container_name && $line =~ /^ {6}/) {
            my ($key, $value) = split / /, $text, 2;
            $results{$current}{$container_name}{$key} = $value;
            next;
        }

        if ($line =~ /^ {4}/) {
            if ($text =~ /^pathname:\s+(.*)/) {
                $results{$current}{pathname} = $1;
                next;
            }
            if ($text eq 'provides:') {
                $container_name = 'provides';
                next;
            }
            if ($text eq 'requirements:') {
                $container_name = 'requirements';
                next;
            }
        }

        if ($line =~ /^ {2}/) {
            $current = $text;
            $results{$current} = {
                provides     => {},
                requirements => {},
            };
            next;
        }
    }

    return \%results;
}

sub sanitize_name {
    my ($module) = @_;
    my ($name) = $module =~ /^(.*)-[^-]+$/;
    return $name // $module;
}

sub get_release {
    my ($author, $distribution) = @_;
    my $url = "http://fastapi.metacpan.org/release/$author/$distribution";
    my $max_retries = 3;
    my $retry_count = 0;
    my $response;

    while ($retry_count < $max_retries) {
        my $ua = HTTP::Tiny->new(
            timeout => 10,
            agent => 'BazelRulesPerlCpanCompiler/1.0'
        );

        $response = $ua->get($url);

        if ($response->{success}) {
            last;
        } elsif ($response->{status} =~ /^5\d{2}$/) {
            warn "5xx error received, retrying...\n";
            $retry_count++;
            sleep(0.05);
        } else {
            die "Failed to fetch $url: $response->{status} $response->{reason}";
        }
    }

    die "Failed to fetch $url after $max_retries retries: $response->{status} $response->{reason}" if $retry_count == $max_retries;

    my $data = decode_json($response->{content});
    die "No release key in response" unless $data->{release};

    return $data->{release};
}

sub carton_install {
    my ($cpanfile) = @_;
    my $carton = Carton::CLI->new;

    my $tempdir = tempdir(CLEANUP => 1);
    my $abs_tempdir = abs_path($tempdir);

    my @args = (
        '--cpanfile' => $cpanfile,
        '--path'     => $abs_tempdir,
    );

    $carton->cmd_install(@args);
}

sub main {
    if (exists $ENV{BUILD_WORKSPACE_DIRECTORY} && -d $ENV{BUILD_WORKSPACE_DIRECTORY}) {
        chdir $ENV{BUILD_WORKSPACE_DIRECTORY}
            or die "Failed to chdir to $ENV{BUILD_WORKSPACE_DIRECTORY}: $!";
    }

    my %args = parse_args();
    my $snapshot_file = "$args{cpanfile}.snapshot";

    unless ($args{incremental}) {
        carton_install($args{cpanfile});
    } else {
        die "Expected snapshot file to exist for incremental mode: $snapshot_file\n"
            unless -f $snapshot_file;
    }

    my $content = read_file($snapshot_file);
    my $snapshot = deserialize_cpanfile_snapshot($content);

    my %lockfile;

    for my $module (keys %$snapshot) {
        my $data = $snapshot->{$module};
        my %dependencies;

        for my $req (keys %{$data->{requirements}}) {
            for my $mod (keys %$snapshot) {
                if (exists $snapshot->{$mod}{provides}{$req}) {
                    $dependencies{sanitize_name($mod)} = 1;
                    last;
                }
            }
        }

        my ($author) = ($data->{pathname} =~ m|^\w/\w\w/([^\/]+)/|) or die "Failed to extract author from pathname: $data->{pathname}\n";

        my $release = get_release($author, $module);
        my $key = sanitize_name($release->{name});

        $lockfile{$key} = {
            dependencies => [ sort keys %dependencies ],
            sha256       => $release->{checksum_sha256},
            strip_prefix => $module,
            url          => $release->{download_url},
        };
    }

    my $json = JSON::PP->new->canonical->pretty->encode(\%lockfile);
    write_file($args{lockfile}, $json);
    print "Lockfile written to: $args{lockfile}\n"
}

main();
