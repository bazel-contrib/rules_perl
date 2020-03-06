package Test::Mock::Simple;

use 5.008008;
use strict;
use warnings;

our $VERSION = '0.10';

my $allow_new_methods = 0;

sub new {
  my $package = shift;
  my $class = ref($package) || $package;

  my $self = {@_};
  bless($self, $class);

  if (!$self->{module}) {
    require Carp;
    Carp::croak("No module name provided to mock");
  }

  my $module_location;
  if ($self->{module_location}) {
    $module_location = $self->{module_location};
  }
  else {
    $module_location = $self->{module} . '.pm';
    $module_location =~ s/::/\//g;
  }

  if ($self->{no_load}) {
    $INC{$module_location} = 1;
  }
  else {
    require $module_location;
  }

  $allow_new_methods = 1 if $self->{allow_new_methods} || $self->{no_load};

  return $self;
}

sub add {
  my $self = shift;
  my $name = shift;
  my $sub = shift;

  return if $ENV{TEST_MOCK_SIMPLE_DISABLE};

  if (!$name) {
    require Carp;
    Carp::croak("No method name provided to mock");
  }
  if (!$sub) {
    require Carp;
    Carp::croak("No sub ref provided to mock");
  }

  if (!$allow_new_methods) {
      die("Module (" . $self->{module} . ") does not have a method named '$name'\n")
        unless $self->{module}->can($name);
  }

  {
    no strict;
    no warnings;

    *{$self->{module} . '::' . $name} = $sub;
  }
}

1;
__END__

=head1 NAME

Test::Mock::Simple - A simple way to mock out parts of or a whole module.

=head1 SYNOPSIS

  use Test::Mock::Simple;

  my $total = 0;

  # Original::Module has methods increase, decrease, and sum
  my $mock = Test::Mock::Simple->new(module => 'Original::Module');
  $mock->add(increase => sub { shift; return $total += shift; });
  $mock->add(decrease => sub { shift; return $total -= shift; });

  my $obj = Original::Module->new();
  $obj->increase(5);
  $obj->decrease(2);
  print $obj->sum . "\n"; # prints 3

=head1 DESCRIPTION

This is a simple way of overriding any number of methods for a given object/class.

Can be used directly in test (or any) files, but best practice (IMHO) is to
create a 'Mock' module and using it instead of directly using the module in any
tests. The goal is to write a test which passes whether Mocking is being used or
not. See TEST_MOCK_SIMPLE_DISABLE below.

The default behavior is to not allow adding methods that do not exist.  This
should stop mistyped method names when attempting to mock existing methods.
See allow_new_methods below to change this behavior.

Why another Mock module?  I needed something simple with no bells or whistles
that only overrode certain methods of a given module. It's more work, but there
aren't any conflicts.

This module can not do anything about BEGIN, END, or other special name code
blocks.  To changes these see B's (The Perl Compiler Backend) begin_av, end_av,
etc. methods.

=head3 Environmental Variables

=over 4

=item TEST_MOCK_SIMPLE_DISABLE

If set to true (preferably 1) then 'add' is disabled.

=back

=head3 Methods

=over 4

=item new

Create a new mock simple object.

=over 4

=item module

The name of the module that is being mocked.  The module will be loaded
immediately (by requiring it).

NOTE: since require is being used to load the module it's import method is not
being called.  This may change in later versions.

=back

=over 4

=item module_location

module_location expects a PATHNAME to the file (relative to the @INC paths) which
contains the namespace (or module) that you want to mock.

This is useful when a single file declares multiple namespaces or in the event of bad
coding where the module's namespace does not map to the module's location.

Example:

  use Test::Mock::Simple;

  my $mock = Test::Mock::Simple->new(
    module          => 'Original::Module',
    module_location => 'Modules/Orignal/Module.pm',
  );

=back

=over 4

=item allow_new_methods

To create methods that do not exist in the module that is being mocked.

The default behavior is to not allow adding methods that do not exist.  This
should stop mistyping method names when attempting to mock existing methods.

=back

=over 4

=item no_load

Default behavior is to load the real module before overriding individual methods.

If this is not desired set no_load to 1 which will stop this from happening.

If set then you are required to mock the whole module (or at least every command
required for code to work).

Setting no_load to 1 will force allow_new_methods to 1 as well. This is done since
without the module actually loaded there is no way of knowing what methods the
module has.

=back

=item add

This allows for the creation of a new method (subroutine) that will override the
existing one. Think of it as 'add'ing a mocked method to override the existing
one.

=back

=head1 AUTHOR

Erik Tank, E<lt>tank@jundy.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Erik Tank

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
